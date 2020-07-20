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

defmodule Astarte.Flow.Blocks.DETSStorage do
  use GenServer

  alias Astarte.Flow.Config

  @behaviour Astarte.Flow.Blocks.Storage

  @table_name :blocks

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  @doc "List the blocks for a specific realm"
  @spec list_blocks(realm :: String.t()) :: [Astarte.Flow.Blocks.Block.t()]
  def list_blocks(realm) do
    match_pattern = {{realm, :_}, :"$1"}

    :dets.match(@table_name, match_pattern)
    |> List.flatten()
  end

  @impl true
  @doc "Fetch a block given its realm and its name"
  @spec fetch_block(realm :: String.t(), name :: String.t()) ::
          {:ok, Astarte.Flow.Blocks.Block.t()} | {:error, reason :: term()}
  def fetch_block(realm, name) do
    case :dets.lookup(@table_name, {realm, name}) do
      [] ->
        {:error, :not_found}

      [{{^realm, ^name}, block}] ->
        {:ok, block}
    end
  end

  @impl true
  @doc "Insert a block into the dets table"
  @spec insert_block(realm :: String.t(), block :: Astarte.Flow.Blocks.Block.t()) ::
          :ok | {:error, reason :: term()}
  def insert_block(realm, block) do
    # This must go through the process since only the owner can write to the table
    GenServer.call(__MODULE__, {:insert_block, realm, block})
  end

  @impl true
  @doc "Delete a block from the dets table"
  @spec delete_block(realm :: String.t(), name :: String.t()) ::
          :ok | {:error, reason :: term()}
  def delete_block(realm, name) do
    # This must go through the process since only the owner can write to the table
    GenServer.call(__MODULE__, {:delete_block, realm, name})
  end

  @impl true
  def init(_args) do
    file =
      Config.persistency_dir!()
      |> Path.expand()
      |> Path.join("blocks")
      |> to_charlist()

    case :dets.open_file(@table_name, type: :set, file: file) do
      {:ok, table} ->
        {:ok, table}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:insert_block, realm, block}, _from, table) do
    entry = {{realm, block.name}, block}

    result =
      case :dets.insert_new(table, entry) do
        true ->
          :ok

        false ->
          {:error, :already_existing_block}

        {:error, reason} ->
          {:error, reason}
      end

    {:reply, result, table}
  end

  def handle_call({:delete_block, realm, name}, _from, table) do
    result = :dets.delete(table, {realm, name})

    {:reply, result, table}
  end
end
