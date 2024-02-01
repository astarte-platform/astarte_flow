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

defmodule Astarte.FlowWeb.PipelineControllerTest do
  use Astarte.FlowWeb.ConnCase

  alias Astarte.Flow.AuthTestHelper

  alias Astarte.Flow.Pipelines.Pipeline

  import Mox

  @realm "test"

  @name "my-pipeline"
  @source ~s'random_source | http_sink.url(${$.config.url})'
  @description "My super useful pipeline"
  @schema %{
    "$id" => "https://astarte-platform.org/specs/astarte_flow/to_json.json",
    "$schema" => "http://json-schema.org/draft-07/schema#",
    "title" => "PipelineConfig",
    "type" => "object",
    "additionalProperties" => false,
    "properties" => %{
      "url" => %{
        "type" => "string",
        "description" => "The URL of the HTTP sink"
      }
    }
  }

  @pipeline %Pipeline{name: @name, source: @source, description: @description, schema: @schema}

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

    test "lists all pipelines", %{conn: conn} do
      PipelinesStorageMock
      |> expect(:list_pipelines, fn realm ->
        assert realm == @realm

        [@pipeline]
      end)

      conn = get(conn, Routes.pipeline_path(conn, :index, @realm))
      assert json_response(conn, 200)["data"] == [@name]
    end
  end

  describe "show" do
    setup [:set_mox_from_context, :setup_public_key_provider, :verify_on_exit!]

    test "renders pipeline", %{conn: conn} do
      PipelinesStorageMock
      |> expect(:fetch_pipeline, fn realm, name ->
        assert realm == @realm
        assert name == @name

        {:ok, @pipeline}
      end)

      conn = get(conn, Routes.pipeline_path(conn, :show, @realm, @name))

      assert %{
               "name" => @name,
               "source" => @source,
               "description" => @description,
               "schema" => @schema
             } == json_response(conn, 200)["data"]
    end

    test "renders 404 when not found", %{conn: conn} do
      PipelinesStorageMock
      |> expect(:fetch_pipeline, fn _realm, _name ->
        {:error, :not_found}
      end)

      conn = get(conn, Routes.pipeline_path(conn, :show, @realm, "notexisting"))
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "create" do
    setup [:set_mox_from_context, :setup_public_key_provider, :verify_on_exit!]

    test "fails with invalid name", %{conn: conn} do
      params = %{
        name: "an)=invalid_name",
        description: @description,
        source: @source
      }

      conn = post(conn, Routes.pipeline_path(conn, :create, @realm), data: params)

      assert json_response(conn, 422)["errors"]["name"] != nil
    end

    test "fails with invalid source", %{conn: conn} do
      params = %{
        name: @name,
        description: @description,
        source: "invalid_source .."
      }

      conn = post(conn, Routes.pipeline_path(conn, :create, @realm), data: params)

      assert json_response(conn, 422)["errors"]["source"] != nil
    end

    test "fails with invalid schema", %{conn: conn} do
      params = %{
        name: @name,
        description: @description,
        source: @source,
        schema: %{required: 42}
      }

      conn = post(conn, Routes.pipeline_path(conn, :create, @realm), data: params)

      assert json_response(conn, 422)["errors"]["schema"] != nil
    end

    test "creates and renders a valid pipeline", %{conn: conn} do
      PipelinesStorageMock
      |> expect(:insert_pipeline, fn realm, %Pipeline{} = pipeline ->
        assert realm == @realm
        assert pipeline.name == @name
        assert pipeline.description == @description
        assert pipeline.source == @source
        assert pipeline.schema == @schema

        :ok
      end)
      |> expect(:fetch_pipeline, fn realm, name ->
        assert realm == @realm
        assert name == @name

        {:ok, @pipeline}
      end)

      params = %{
        name: @name,
        description: @description,
        source: @source,
        schema: @schema
      }

      create_conn = post(conn, Routes.pipeline_path(conn, :create, @realm), data: params)

      assert %{
               "name" => @name,
               "source" => @source,
               "description" => @description,
               "schema" => @schema
             } == json_response(create_conn, 201)["data"]

      show_conn = get(conn, Routes.pipeline_path(conn, :show, @realm, @name))

      assert %{
               "name" => @name,
               "source" => @source,
               "description" => @description,
               "schema" => @schema
             } == json_response(show_conn, 200)["data"]
    end

    test "fails on already existing pipeline", %{conn: conn} do
      PipelinesStorageMock
      |> expect(:insert_pipeline, fn realm, %Pipeline{} = pipeline ->
        assert realm == @realm
        assert pipeline.name == "existing"
        assert pipeline.description == @description
        assert pipeline.source == @source

        {:error, :already_existing_pipeline}
      end)

      params = %{
        name: "existing",
        description: @description,
        source: @source
      }

      create_conn = post(conn, Routes.pipeline_path(conn, :create, @realm), data: params)

      assert json_response(create_conn, 409)["errors"]["detail"] == "Pipeline already exists"
    end
  end

  describe "delete" do
    setup [:setup_public_key_provider]

    test "renders 404 when not found", %{conn: conn} do
      PipelinesStorageMock
      |> expect(:fetch_pipeline, fn _realm, _name ->
        {:error, :not_found}
      end)

      conn = delete(conn, Routes.pipeline_path(conn, :delete, @realm, "notexisting"))
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "deletes an existing pipeline", %{conn: conn} do
      PipelinesStorageMock
      |> expect(:fetch_pipeline, fn realm, name ->
        assert realm == @realm
        assert name == @name

        {:ok, @pipeline}
      end)
      |> expect(:delete_pipeline, fn realm, name ->
        assert realm == @realm
        assert name == @name

        :ok
      end)
      |> expect(:fetch_pipeline, fn _realm, _name ->
        {:error, :not_found}
      end)

      delete_conn = delete(conn, Routes.pipeline_path(conn, :delete, @realm, @name))
      assert response(delete_conn, 204)

      show_conn = get(conn, Routes.pipeline_path(conn, :show, @realm, @name))

      assert json_response(show_conn, 404)
    end
  end

  defp setup_public_key_provider(_context) do
    stub_with(PublicKeyProviderMock, Astarte.Flow.AuthTestHelper)

    :ok
  end
end
