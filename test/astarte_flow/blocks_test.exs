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

defmodule Astarte.Flow.BlocksTest do
  use ExUnit.Case

  alias Astarte.Flow.Blocks
  alias Astarte.Flow.Blocks.Block

  import Mox

  @realm "test"

  @name "interface_filter"
  @source """
  filter
    .script("return string.find(message.key, config.interface_name) ~= nil;")
    .config(${config})
  """
  @block_type "producer_consumer"
  @schema %{
    "$id" => "https://example.com/blocks/interface_filter.json",
    "$schema" => "http://json-schema.org/draft-07/schema#",
    "title" => "InterfaceFilterOptions",
    "type" => "object",
    "additionalProperties" => false,
    "required" => ["interface_name"],
    "properties" => %{
      "interface_name" => %{
        "type" => "string",
        "description" => "The name of the interface that will be allowed by the filter"
      }
    }
  }

  @block %Block{name: @name, source: @source, type: @block_type, schema: @schema}

  describe "list_blocks/1" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "returns all blocks default blocks and custom blocks" do
      BlocksStorageMock
      |> expect(:list_blocks, fn realm ->
        assert realm == @realm

        [@block]
      end)

      default_blocks_number =
        "#{:code.priv_dir(:astarte_flow)}/blocks/*.json"
        |> Path.wildcard()
        |> Enum.count()

      blocks_list = Blocks.list_blocks(@realm)
      assert length(blocks_list) == default_blocks_number + 1
      assert Enum.member?(blocks_list, @block)
    end
  end

  describe "get_block/2" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "returns the existing block with given name" do
      BlocksStorageMock
      |> expect(:fetch_block, fn realm, name ->
        assert realm == @realm
        assert name == @name

        {:ok, @block}
      end)

      assert {:ok, %Block{name: @name, source: @source, type: @block_type, schema: @schema}} =
               Blocks.get_block(@realm, @name)
    end

    test "returns default block with given name" do
      assert {:ok,
              %Block{
                name: "to_json",
                beam_module: Astarte.Flow.Blocks.JsonMapper,
                type: "producer_consumer",
                schema: schema
              }} = Blocks.get_block(@realm, "to_json")

      assert is_map(schema)
    end

    test "returns error with unexisting block" do
      BlocksStorageMock
      |> expect(:fetch_block, fn _realm, _name ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = Blocks.get_block(@realm, "unexisting")
    end
  end

  describe "create_block/2" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "creates and returns a valid block" do
      BlocksStorageMock
      |> expect(:insert_block, fn realm, %Block{} = block ->
        assert realm == @realm
        assert block.name == @name
        assert block.source == @source
        assert block.type == @block_type
        assert block.schema == @schema

        :ok
      end)

      params = %{
        "name" => @name,
        "source" => @source,
        "type" => @block_type,
        "schema" => @schema
      }

      assert {:ok, %Block{name: @name, source: @source, type: @block_type, schema: @schema}} =
               Blocks.create_block(@realm, params)
    end

    test "ignores beam_module for user created blocks" do
      params = %{
        "name" => @name,
        "beam_module" => "Elixir.My.Module",
        "type" => @block_type,
        "schema" => @schema
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Blocks.create_block(@realm, params)
      assert changeset.errors[:source] != nil
    end

    test "fails with invalid schema" do
      schema = %{"required" => 42}

      params = %{
        "name" => "existing",
        "source" => @source,
        "type" => @block_type,
        "schema" => schema
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Blocks.create_block(@realm, params)
      assert changeset.errors[:schema] != nil
    end

    test "returns an error if the block already exists" do
      BlocksStorageMock
      |> expect(:insert_block, fn realm, %Block{} = block ->
        assert realm == @realm
        assert block.name == "existing"
        assert block.source == @source
        assert block.type == @block_type
        assert block.schema == @schema

        {:error, :already_existing_block}
      end)

      params = %{
        "name" => "existing",
        "source" => @source,
        "type" => @block_type,
        "schema" => @schema
      }

      assert {:error, :already_existing_block} = Blocks.create_block(@realm, params)
    end

    test "returns an error if the block conflicts with a default block" do
      params = %{
        "name" => "to_json",
        "source" => @source,
        "type" => @block_type,
        "schema" => @schema
      }

      assert {:error, :already_existing_block} = Blocks.create_block(@realm, params)
    end
  end

  describe "delete_block/2" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "deletes an existing block" do
      BlocksStorageMock
      |> expect(:delete_block, fn realm, name ->
        assert realm == @realm
        assert name == @name

        :ok
      end)

      assert :ok = Blocks.delete_block(@realm, @name)
    end

    test "fails to delete a default block" do
      assert {:error, :cannot_delete_default_block} = Blocks.delete_block(@realm, "to_json")
    end
  end
end
