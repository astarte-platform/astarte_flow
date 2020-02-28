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

defmodule Astarte.Flow.Pipelines.DETSStorage do
  use GenServer

  @behaviour Astarte.Flow.Pipelines.Storage

  @table_name :pipelines

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  @doc "List the pipelines for a specific realm"
  @spec list_pipelines(realm :: String.t()) :: [Astarte.Flow.Pipelines.Pipeline.t()]
  def list_pipelines(realm) do
    match_pattern = {{realm, :_}, :"$1"}

    :dets.match(@table_name, match_pattern)
    |> List.flatten()
  end

  @impl true
  @doc "Fetch a pipeline given its realm and its name"
  @spec fetch_pipeline(realm :: String.t(), name :: String.t()) ::
          {:ok, Astarte.Flow.Pipelines.Pipeline.t()} | {:error, reason :: term()}
  def fetch_pipeline(realm, name) do
    case :dets.lookup(@table_name, {realm, name}) do
      [] ->
        {:error, :not_found}

      [{{^realm, ^name}, pipeline}] ->
        {:ok, pipeline}
    end
  end

  @impl true
  @doc "Insert a pipeline into the dets table"
  @spec insert_pipeline(realm :: String.t(), pipeline :: Astarte.Flow.Pipelines.Pipeline.t()) ::
          :ok | {:error, reason :: term()}
  def insert_pipeline(realm, pipeline) do
    # This must go through the process since only the owner can write to the table
    GenServer.call(__MODULE__, {:insert_pipeline, realm, pipeline})
  end

  @impl true
  @doc "Delete a pipeline from the dets table"
  @spec delete_pipeline(realm :: String.t(), name :: String.t()) ::
          :ok | {:error, reason :: term()}
  def delete_pipeline(realm, name) do
    # This must go through the process since only the owner can write to the table
    GenServer.call(__MODULE__, {:delete_pipeline, realm, name})
  end

  @impl true
  def init(_args) do
    file =
      Application.get_env(:astarte_flow, :persistency_dir, "")
      |> Path.expand()
      |> Path.join("pipelines")
      |> to_charlist()

    case :dets.open_file(@table_name, type: :set, file: file) do
      {:ok, table} ->
        {:ok, table}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:insert_pipeline, realm, pipeline}, _from, table) do
    entry = {{realm, pipeline.name}, pipeline}

    result =
      case :dets.insert_new(table, entry) do
        true ->
          :ok

        false ->
          {:error, :already_existing_pipeline}

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, table}
  end

  def handle_call({:delete_pipeline, realm, name}, _from, table) do
    result = :dets.delete(table, {realm, name})

    {:reply, result, table}
  end
end
