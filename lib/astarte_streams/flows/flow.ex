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

defmodule Astarte.Streams.Flows.Flow do
  @moduledoc """
  This module implements an embedded_schema representing a Flow and also
  the GenServer responsible of starting and monitoring the Flow.
  """

  use GenServer
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Streams.Flows.Flow
  alias Astarte.Streams.Flows.Registry, as: FlowsRegistry
  alias Astarte.Streams.Flows.RealmRegistry
  alias Astarte.Streams.PipelineBuilder
  alias Astarte.Streams.Pipelines
  require Logger

  @primary_key false
  @derive {Phoenix.Param, key: :name}
  embedded_schema do
    field :config, :map
    field :name, :string
    field :pipeline, :string
  end

  @doc false
  def changeset(%Flow{} = flow, attrs) do
    flow
    |> cast(attrs, [:pipeline, :name, :config])
    |> validate_required([:pipeline, :name, :config])
  end

  defmodule State do
    defstruct [
      :realm,
      :flow,
      :pipeline,
      :last_block_pid,
      pipeline_pids: []
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

    with {:ok, pipeline_desc} <- Pipelines.get_pipeline(realm, flow.pipeline),
         pipeline = PipelineBuilder.build(pipeline_desc, %{"config" => flow.config}),
         state = %State{realm: realm, flow: flow, pipeline: pipeline},
         {:ok, state} <- start_pipeline(pipeline, state) do
      _ = Registry.register(RealmRegistry, realm, flow)
      {:ok, state}
    else
      {:error, :not_found} ->
        {:stop, :pipeline_not_found}
    end
  end

  defp start_pipeline(pipeline, state) do
    # We reverse the pipeline, so we're going from the last block to the first one
    Enum.reverse(pipeline)
    |> Enum.reduce_while({:ok, state}, fn
      # This is the last one, no need to connect it to anything
      {block_module, block_opts}, {:ok, %{pipeline_pids: []} = state} ->
        case block_module.start_link(block_opts) do
          {:ok, pid} ->
            _ = Process.monitor(pid)

            {:cont, {:ok, %{state | last_block_pid: pid, pipeline_pids: [pid]}}}

          _any ->
            {:halt, {:error, :start_all_failed}}
        end

      {block_module, block_opts}, {:ok, %{pipeline_pids: [previous | _tail] = pids} = state} ->
        case block_module.start_link(block_opts) do
          {:ok, pid} ->
            _ = Process.monitor(pid)

            GenStage.sync_subscribe(previous, to: pid)

            {:cont, {:ok, %{state | pipeline_pids: [pid | pids]}}}

          _any ->
            {:halt, {:error, :start_all_failed}}
        end
    end)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %State{flow: flow} = state) do
    _ =
      Logger.error("A block crashed with reason #{inspect(reason)}.",
        flow: flow.name,
        tag: "flow_crash"
      )

    {:stop, reason, state}
  end

  @impl true
  def handle_call(:get_flow, _from, %State{flow: flow} = state) do
    {:reply, flow, state}
  end

  def handle_call(:tap, _from, %State{last_block_pid: last_block_pid} = state) do
    stream = GenStage.stream([last_block_pid])
    {:reply, stream, state}
  end
end
