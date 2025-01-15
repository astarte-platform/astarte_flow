#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Flow.Flows.Flow do
  @moduledoc """
  This module implements an embedded_schema representing a Flow and also
  the GenServer responsible of starting and monitoring the Flow.
  """

  use GenServer
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Flow.Blocks.Container
  alias Astarte.Flow.Flows.Flow
  alias Astarte.Flow.Flows.Registry, as: FlowsRegistry
  alias Astarte.Flow.Flows.RealmRegistry
  alias Astarte.Flow.K8s
  alias Astarte.Flow.PipelineBuilder
  alias Astarte.Flow.Pipelines
  alias Astarte.Flow.Pipelines.Pipeline
  require Logger

  @retry_timeout_ms 10_000

  @primary_key false
  @derive {Phoenix.Param, key: :name}
  embedded_schema do
    field :config, :map, default: %{}
    field :name, :string
    field :pipeline, :string
  end

  @doc false
  def changeset(%Flow{} = flow, attrs) do
    flow
    |> cast(attrs, [:pipeline, :name, :config])
    |> validate_required([:pipeline, :name])
    |> validate_format(:name, ~r/^[a-zA-Z0-9][a-zA-Z0-9-]+$/)
  end

  defmodule State do
    defstruct [
      :realm,
      :flow,
      :pipeline,
      :status,
      container_block_pids: [],
      native_block_pids: [],
      block_pids: []
    ]
  end

  @doc """
  Start a Flow as linked process.

  Arguments:
  - `realm`: the realm the Flow belongs to.
  - `flow`: a `%Flow{}` struct with the parameters of the Flow.
  """
  def start_link(args) do
    realm = Keyword.fetch!(args, :realm)
    flow = Keyword.fetch!(args, :flow)

    GenServer.start_link(__MODULE__, args, name: via_tuple(realm, flow.name))
  end

  @doc """
  Returns the `%Flow{}` struct that was used to create the flow.
  """
  def get_flow(realm, name) do
    via_tuple(realm, name)
    |> get_flow()
  end

  @doc """
  See `get_flow/2`.
  """
  def get_flow(pid_or_via_tuple) do
    GenServer.call(pid_or_via_tuple, :get_flow)
  end

  @doc """
  Returns a `Stream` created by calling `GenStage.stream/1` on the last stage of the Flow.
  """
  def tap(realm, name) do
    via_tuple(realm, name)
    |> GenServer.call(:tap)
  end

  defp via_tuple(realm, name) do
    {:via, Registry, {FlowsRegistry, {realm, name}}}
  end

  @impl true
  def init(args) do
    Process.flag(:trap_exit, true)

    realm = Keyword.fetch!(args, :realm)
    flow = Keyword.fetch!(args, :flow)

    _ = Logger.info("Starting Flow #{flow.name}.", flow: flow.name, tag: "flow_start")

    with {:ok, %Pipeline{source: source}} <- Pipelines.get_pipeline(realm, flow.pipeline),
         {:ok, pipeline} <- PipelineBuilder.build(realm, source, %{"config" => flow.config}),
         state = %State{realm: realm, flow: flow, pipeline: pipeline},
         {:ok, state} <- start_flow(realm, flow, pipeline, state) do
      _ = Registry.register(RealmRegistry, realm, flow)
      # Right here all blocks are started, next step is bringing up the containers
      Logger.debug("Flow #{flow.name} initialized.")

      if state.container_block_pids == [] do
        # No containers, so no need to use K8s
        send(self(), :connect_blocks)

        {:ok, %{state | status: :connecting_blocks}}
      else
        send(self(), :initialize_k8s_flow)

        {:ok, %{state | status: :collecting_containers}}
      end
    else
      {:error, :not_found} ->
        {:stop, :pipeline_not_found}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp start_flow(realm, flow, pipeline, state) do
    id_prefix = "#{realm}-#{flow.name}"

    with {:ok, {block_pids, container_block_pids, native_block_pids, _}} <-
           start_blocks(id_prefix, pipeline, flow.config) do
      {:ok,
       %{
         state
         | block_pids: block_pids,
           native_block_pids: native_block_pids,
           container_block_pids: container_block_pids
       }}
    end
  end

  defp start_blocks(id_prefix, pipeline, flow_config) do
    Enum.reduce_while(pipeline, {:ok, {[], [], [], 0}}, fn
      # Special case: container block
      {Container = block_module, block_opts},
      {:ok, {block_pids, container_block_pids, native_block_pids, block_idx}} ->
        # Pass a deterministic id
        id = id_prefix <> to_string(block_idx)

        full_opts =
          block_opts
          |> Keyword.put(:id, id)
          |> Keyword.put(:config, flow_config)

        case start_block(block_module, full_opts) do
          {:ok, pid} ->
            new_block_pids = [pid | block_pids]
            new_container_block_pids = [pid | container_block_pids]

            {:cont,
             {:ok, {new_block_pids, new_container_block_pids, native_block_pids, block_idx + 1}}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end

      {block_module, block_opts},
      {:ok, {block_pids, container_block_pids, native_block_pids, block_idx}} ->
        case start_block(block_module, block_opts) do
          {:ok, pid} ->
            new_block_pids = [pid | block_pids]
            new_native_block_pids = [pid | native_block_pids]

            {:cont,
             {:ok, {new_block_pids, container_block_pids, new_native_block_pids, block_idx + 1}}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end

  defp start_block(block_module, block_opts) do
    case block_module.start_link(block_opts) do
      {:ok, pid} ->
        {:ok, pid}

      error ->
        _ =
          Logger.error(
            "Could not start block #{inspect(block_module)} with opts #{inspect(block_opts)}: #{inspect(error)}"
          )

        {:error, :block_start_failed}
    end
  end

  @impl true
  def handle_info({:EXIT, port, _reason}, state) when is_port(port) do
    # Ignore port exits
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, reason}, state)
      when is_pid(pid) and reason in [:normal, :shutdown] do
    # Don't log on normal or shutdown exits
    {:stop, reason, state}
  end

  def handle_info({:EXIT, pid, reason}, %State{flow: flow} = state) when is_pid(pid) do
    _ =
      Logger.error("A block crashed with reason #{inspect(reason)}.",
        flow: flow.name,
        tag: "flow_block_crash"
      )

    {:stop, reason, state}
  end

  def handle_info(:initialize_k8s_flow, state) do
    %{
      realm: realm,
      flow: flow,
      native_block_pids: native_block_pids,
      container_block_pids: container_block_pids
    } = state

    with {:ok, container_blocks} <- collect_container_blocks(container_block_pids),
         # TODO: passing native_block_pids is ok here, since K8s just "counts" native blocks right now
         :ok <- K8s.create_flow(realm, flow.name, container_blocks, native_block_pids) do
      Logger.debug("Flow #{flow.name} K8s containers created.")
      send(self(), :check_flow_status)

      {:noreply, %{state | status: :creating_containers}}
    else
      error ->
        Logger.warning(
          "K8s initialization failed: #{inspect(error)}. Retrying in #{@retry_timeout_ms} ms.",
          flow: flow.name
        )

        Process.send_after(self(), :initialize_k8s_flow, @retry_timeout_ms)
        {:noreply, state}
    end
  end

  def handle_info(:check_flow_status, %State{flow: flow} = state) do
    case K8s.flow_status(flow.name) do
      {:ok, "Flowing"} ->
        Logger.debug("Flow #{flow.name} K8s in Flowing state.")

        send(self(), :connect_blocks)
        {:noreply, %{state | status: :connecting_blocks}}

      _other ->
        Process.send_after(self(), :check_flow_status, @retry_timeout_ms)

        {:noreply, state}
    end

    {:noreply, %{state | status: :waiting_blocks_connection}}
  end

  def handle_info(:connect_blocks, state) do
    %{
      block_pids: block_pids,
      flow: flow
    } = state

    # block_pids is populated reducing on the pipeline, so the first element is the last block
    with :ok <- connect_blocks(block_pids) do
      Logger.debug("Flow #{flow.name} is ready.")

      {:noreply, %{state | status: :flowing}}
    else
      error ->
        Logger.warning("Block connection failed: #{inspect(error)}.",
          flow: flow.name,
          tag: "flow_block_connection_failed"
        )

        # TODO: we don't try to recover from this state right now
        {:stop, state}
    end
  end

  defp connect_blocks([subscriber, publisher | tail]) do
    with {:ok, _subscription_tag} <- GenStage.sync_subscribe(subscriber, to: publisher) do
      connect_blocks([publisher | tail])
    end
  end

  defp connect_blocks([_first_publisher]) do
    :ok
  end

  defp collect_container_blocks(container_block_pids) do
    Enum.reduce_while(container_block_pids, {:ok, []}, fn pid, {:ok, acc} ->
      case Container.get_container_block(pid) do
        {:ok, container_block} ->
          {:cont, {:ok, [container_block | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  @impl true
  def handle_call(:get_flow, _from, %State{flow: flow} = state) do
    {:reply, flow, state}
  end

  def handle_call(:tap, _from, %State{block_pids: [last_block_pid | _tail]} = state) do
    # block_pids is populated reducing on the pipeline, so the first element is the last block
    stream = GenStage.stream([last_block_pid])
    {:reply, stream, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.container_block_pids != [] do
      K8s.try_delete_flow(state.flow.name)
    end
  end
end
