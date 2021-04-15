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

defmodule Astarte.Flow.PipelinesTest do
  use ExUnit.Case

  alias Astarte.Flow.Pipelines
  alias Astarte.Flow.Pipelines.Pipeline

  import Mox

  @realm "test"

  @name "my-pipeline"
  @source ~s'random_source | http_sink.url("http://example.com/my_url")'
  @description "My super useful pipeline"

  @pipeline %Pipeline{name: @name, source: @source, description: @description}

  describe "list_pipelines/1" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "returns all pipelines" do
      PipelinesStorageMock
      |> expect(:list_pipelines, fn realm ->
        assert realm == @realm

        [@pipeline]
      end)

      assert Pipelines.list_pipelines(@realm) == [@pipeline]
    end
  end

  describe "get_pipeline/2" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "returns the existing pipeline with given name" do
      PipelinesStorageMock
      |> expect(:fetch_pipeline, fn realm, name ->
        assert realm == @realm
        assert name == @name

        {:ok, @pipeline}
      end)

      assert {:ok, %Pipeline{name: @name, source: @source, description: @description}} =
               Pipelines.get_pipeline(@realm, @name)
    end

    test "returns error with unexisting pipeline" do
      PipelinesStorageMock
      |> expect(:fetch_pipeline, fn _realm, _name ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = Pipelines.get_pipeline(@realm, "unexisting")
    end
  end

  describe "create_pipeline/2" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "creates and returns a valid pipeline" do
      PipelinesStorageMock
      |> expect(:insert_pipeline, fn realm, %Pipeline{} = pipeline ->
        assert realm == @realm
        assert pipeline.name == @name
        assert pipeline.description == @description
        assert pipeline.source == @source

        :ok
      end)

      params = %{
        "name" => @name,
        "description" => @description,
        "source" => @source
      }

      assert {:ok, %Pipeline{name: @name, source: @source, description: @description}} =
               Pipelines.create_pipeline(@realm, params)
    end

    test "creates a pipeline with a schema" do
      schema = %{
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

      source = ~s'random_source | http_sink.url(${$.config.url})'

      PipelinesStorageMock
      |> expect(:insert_pipeline, fn realm, %Pipeline{} = pipeline ->
        assert realm == @realm
        assert pipeline.name == @name
        assert pipeline.description == @description
        assert pipeline.source == source
        assert pipeline.schema == schema

        :ok
      end)

      params = %{
        "name" => @name,
        "description" => @description,
        "source" => source,
        "schema" => schema
      }

      assert {:ok, %Pipeline{name: @name, source: ^source, description: @description}} =
               Pipelines.create_pipeline(@realm, params)
    end

    test "fails with invalid schema" do
      schema = %{"required" => 42}

      params = %{
        "name" => @name,
        "description" => @description,
        "source" => @source,
        "schema" => schema
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Pipelines.create_pipeline(@realm, params)
      assert changeset.errors[:schema] != nil
    end

    test "uses empty string as default description" do
      PipelinesStorageMock
      |> expect(:insert_pipeline, fn realm, %Pipeline{} = pipeline ->
        assert realm == @realm
        assert pipeline.name == @name
        assert pipeline.description == ""
        assert pipeline.source == @source

        :ok
      end)

      params = %{
        "name" => @name,
        "source" => @source
      }

      assert {:ok, %Pipeline{name: @name, source: @source, description: ""}} =
               Pipelines.create_pipeline(@realm, params)
    end

    test "returns an error if the pipeline already exists" do
      PipelinesStorageMock
      |> expect(:insert_pipeline, fn realm, %Pipeline{} = pipeline ->
        assert realm == @realm
        assert pipeline.name == "existing"
        assert pipeline.description == @description
        assert pipeline.source == @source

        {:error, :already_existing_pipeline}
      end)

      params = %{
        "name" => "existing",
        "description" => @description,
        "source" => @source
      }

      assert {:error, :already_existing_pipeline} = Pipelines.create_pipeline(@realm, params)
    end
  end

  describe "delete_pipeline/2" do
    setup [:set_mox_from_context, :verify_on_exit!]

    test "deletes and existing pipeline" do
      PipelinesStorageMock
      |> expect(:delete_pipeline, fn realm, name ->
        assert realm == @realm
        assert name == @name

        :ok
      end)

      assert :ok = Pipelines.delete_pipeline(@realm, @name)
    end
  end
end
