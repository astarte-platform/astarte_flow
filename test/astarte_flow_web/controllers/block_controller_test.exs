#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.FlowWeb.BlockControllerTest do
  use Astarte.FlowWeb.ConnCase

  alias Astarte.Flow.AuthTestHelper

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
    "$schema" => "http://json-schema.org/draft-04/schema#",
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

  setup %{conn: conn} do
    jwt = AuthTestHelper.gen_jwt_all_access_token()

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer " <> jwt)

    {:ok, conn: conn}
  end

  describe "index" do
    setup [:set_mox_from_context, :setup_public_key_provider, :verify_on_exit!]

    test "lists all blocks", %{conn: conn} do
      BlocksStorageMock
      |> expect(:list_blocks, fn realm ->
        assert realm == @realm

        [@block]
      end)

      conn = get(conn, ~p"/v1/#{@realm}/blocks")
      blocks = json_response(conn, 200)["data"]

      user_block = Enum.find(blocks, &(&1["name"] == @name))
      assert user_block["source"] == @source
      assert user_block["type"] == @block_type
      assert user_block["schema"] == @schema
    end
  end

  describe "show" do
    setup [:set_mox_from_context, :setup_public_key_provider, :verify_on_exit!]

    test "renders block", %{conn: conn} do
      BlocksStorageMock
      |> expect(:fetch_block, fn realm, name ->
        assert realm == @realm
        assert name == @name

        {:ok, @block}
      end)

      conn = get(conn, ~p"/v1/#{@realm}/blocks/#{@name}")

      assert %{
               "name" => @name,
               "source" => @source,
               "type" => @block_type,
               "schema" => @schema
             } == json_response(conn, 200)["data"]
    end

    test "renders default block", %{conn: conn} do
      conn = get(conn, ~p"/v1/#{@realm}/blocks/to_json")

      assert %{
               "name" => "to_json",
               "beam_module" => "Elixir.Astarte.Flow.Blocks.JsonMapper",
               "type" => "producer_consumer",
               "schema" => schema
             } = json_response(conn, 200)["data"]

      assert is_map(schema)
    end

    test "renders 404 when not found", %{conn: conn} do
      BlocksStorageMock
      |> expect(:fetch_block, fn _realm, _name ->
        {:error, :not_found}
      end)

      conn = get(conn, ~p"/v1/#{@realm}/blocks/notexisting")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "create" do
    setup [:set_mox_from_context, :setup_public_key_provider, :verify_on_exit!]

    test "fails with invalid name", %{conn: conn} do
      params = %{
        name: "an)=invalid_name",
        source: @source,
        type: @block_type,
        schema: @schema
      }

      conn = post(conn, ~p"/v1/#{@realm}/blocks", data: params)

      assert json_response(conn, 422)["errors"]["name"] != nil
    end

    test "fails with invalid source", %{conn: conn} do
      params = %{
        name: @name,
        source: "invalid_source ..",
        type: @block_type,
        schema: @schema
      }

      conn = post(conn, ~p"/v1/#{@realm}/blocks", data: params)

      assert json_response(conn, 422)["errors"]["source"] != nil
    end

    test "fails with invalid schema", %{conn: conn} do
      params = %{
        name: @name,
        source: @source,
        type: @block_type,
        schema: %{required: 42}
      }

      conn = post(conn, ~p"/v1/#{@realm}/blocks", data: params)

      assert json_response(conn, 422)["errors"]["schema"] != nil
    end

    test "creates and renders a valid block", %{conn: conn} do
      BlocksStorageMock
      |> expect(:insert_block, fn realm, %Block{} = block ->
        assert realm == @realm
        assert block.name == @name
        assert block.source == @source
        assert block.type == @block_type
        assert block.schema == @schema

        :ok
      end)
      |> expect(:fetch_block, fn realm, name ->
        assert realm == @realm
        assert name == @name

        {:ok, @block}
      end)

      params = %{
        name: @name,
        source: @source,
        type: @block_type,
        schema: @schema
      }

      create_conn = post(conn, ~p"/v1/#{@realm}/blocks", data: params)

      assert %{
               "name" => @name,
               "source" => @source,
               "type" => @block_type,
               "schema" => @schema
             } == json_response(create_conn, 201)["data"]

      show_conn = get(conn, ~p"/v1/#{@realm}/blocks/#{@name}")

      assert %{
               "name" => @name,
               "source" => @source,
               "type" => @block_type,
               "schema" => @schema
             } == json_response(show_conn, 200)["data"]
    end

    test "fails on already existing block", %{conn: conn} do
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
        name: "existing",
        source: @source,
        type: @block_type,
        schema: @schema
      }

      create_conn = post(conn, ~p"/v1/#{@realm}/blocks", data: params)

      assert json_response(create_conn, 409)["errors"]["detail"] == "Block already exists"
    end

    test "fails with name conflict with default block", %{conn: conn} do
      params = %{
        name: "to_json",
        source: @source,
        type: @block_type,
        schema: @schema
      }

      create_conn = post(conn, ~p"/v1/#{@realm}/blocks", data: params)

      assert json_response(create_conn, 409)["errors"]["detail"] == "Block already exists"
    end
  end

  describe "delete" do
    setup [:setup_public_key_provider]

    test "renders 404 when not found", %{conn: conn} do
      BlocksStorageMock
      |> expect(:fetch_block, fn _realm, _name ->
        {:error, :not_found}
      end)

      conn = delete(conn, ~p"/v1/#{@realm}/blocks/notexisting")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "deletes an existing block", %{conn: conn} do
      BlocksStorageMock
      |> expect(:fetch_block, fn realm, name ->
        assert realm == @realm
        assert name == @name

        {:ok, @block}
      end)
      |> expect(:delete_block, fn realm, name ->
        assert realm == @realm
        assert name == @name

        :ok
      end)
      |> expect(:fetch_block, fn _realm, _name ->
        {:error, :not_found}
      end)

      delete_conn = delete(conn, ~p"/v1/#{@realm}/blocks/#{@name}")
      assert response(delete_conn, 204)

      show_conn = get(conn, ~p"/v1/#{@realm}/blocks/#{@name}")

      assert json_response(show_conn, 404)
    end
  end

  defp setup_public_key_provider(_context) do
    stub_with(PublicKeyProviderMock, Astarte.Flow.AuthTestHelper)

    :ok
  end
end
