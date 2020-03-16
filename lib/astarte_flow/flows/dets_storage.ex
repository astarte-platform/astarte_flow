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

defmodule Astarte.Flow.Flows.DETSStorage do
  use GenServer

  @behaviour Astarte.Flow.Flows.Storage

  @table_name :flows

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  @doc "Return a list of all saved Flows in the form `{realm, %Flow{}}`"
  @spec get_all_flows :: [{realm :: String, Astarte.Flow.Flows.Flow.t()}]
  def get_all_flows do
    match_pattern = {{:"$1", :_}, :"$2"}

    :dets.match(@table_name, match_pattern)
    |> Enum.map(fn [realm, flow] -> {realm, flow} end)
  end

  @impl true
  @doc "Insert a flow into the dets table"
  @spec insert_flow(realm :: String.t(), flow :: Astarte.Flow.Flows.Flow.t()) ::
          :ok | {:error, reason :: term()}
  def insert_flow(realm, flow) do
    # This must go through the process since only the owner can write to the table
    GenServer.call(__MODULE__, {:insert_flow, realm, flow})
  end

  @impl true
  @doc "Delete a flow from the dets table"
  @spec delete_flow(realm :: String.t(), name :: String.t()) ::
          :ok | {:error, reason :: term()}
  def delete_flow(realm, name) do
    # This must go through the process since only the owner can write to the table
    GenServer.call(__MODULE__, {:delete_flow, realm, name})
  end

  @impl true
  def init(_args) do
    file =
      Application.get_env(:astarte_flow, :persistency_dir, "")
      |> Path.expand()
      |> Path.join("flows")
      |> to_charlist()

    case :dets.open_file(@table_name, type: :set, file: file) do
      {:ok, table} ->
        {:ok, table}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:insert_flow, realm, flow}, _from, table) do
    entry = {{realm, flow.name}, flow}

    result =
      case :dets.insert_new(table, entry) do
        true ->
          :ok

        false ->
          {:error, :already_existing_flow}

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, table}
  end

  def handle_call({:delete_flow, realm, name}, _from, table) do
    result = :dets.delete(table, {realm, name})

    {:reply, result, table}
  end
end
