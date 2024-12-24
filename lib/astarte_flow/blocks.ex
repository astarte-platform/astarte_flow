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

defmodule Astarte.Flow.Blocks do
  require Logger

  alias Astarte.Flow.Blocks.Block
  alias Astarte.Flow.Blocks.DefaultBlocks
  alias Astarte.Flow.Blocks.DETSStorage

  @storage Application.compile_env(:astarte_flow, :blocks_storage_mod, DETSStorage)

  def list_blocks(realm) when is_binary(realm) do
    @storage.list_blocks(realm) ++ DefaultBlocks.list()
  end

  def get_block(realm, name) when is_binary(realm) and is_binary(name) do
    with {:error, :not_found} <- DefaultBlocks.fetch(name) do
      @storage.fetch_block(realm, name)
    else
      {:ok, block} -> {:ok, block}
    end
  end

  def create_block(realm, params) when is_binary(realm) and is_map(params) do
    changeset = Block.changeset(%Block{}, params)

    with {:ok, %Block{} = block} <- Ecto.Changeset.apply_action(changeset, :insert),
         :ok <- check_default_blocks_conflict(block),
         :ok <- @storage.insert_block(realm, block) do
      {:ok, block}
    end
  end

  def delete_block(realm, name) when is_binary(realm) and is_binary(name) do
    case DefaultBlocks.fetch(name) do
      {:ok, _block} ->
        {:error, :cannot_delete_default_block}

      {:error, :not_found} ->
        @storage.delete_block(realm, name)
    end
  end

  def check_default_blocks_conflict(%Block{name: name} = _block) do
    case DefaultBlocks.fetch(name) do
      {:ok, _block} ->
        {:error, :already_existing_block}

      {:error, :not_found} ->
        :ok
    end
  end
end
