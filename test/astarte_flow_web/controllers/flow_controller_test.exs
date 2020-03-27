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

defmodule Astarte.FlowWeb.FlowControllerTest do
  use Astarte.FlowWeb.ConnCase

  alias Astarte.Flow.AuthTestHelper

  alias Astarte.Flow.Flows
  alias Astarte.Flow.Flows.Supervisor, as: FlowsSupervisor
  import Mox

  @realm "test"
  @create_attrs %{"name" => "test", "pipeline" => "test", "config" => %{"key" => "test"}}
  @invalid_attrs %{"name" => 42, "pipeline" => "test", "config" => %{"key" => "test"}}

  def fixture(:flow) do
    FlowsStorageMock
    |> expect(:insert_flow, fn @realm, _flow ->
      :ok
    end)

    {:ok, flow} = Flows.create_flow(@realm, @create_attrs)
    flow
  end

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

    test "lists all flows", %{conn: conn} do
      conn = get(conn, Routes.flow_path(conn, :index, @realm))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create flow" do
    setup [
      :set_mox_from_context,
      :setup_public_key_provider,
      :cleanup_flows,
      :populate_pipelines,
      :verify_on_exit!
    ]

    test "renders flow when data is valid", %{conn: conn} do
      FlowsStorageMock
      |> expect(:insert_flow, fn realm, flow ->
        assert realm == @realm
        assert flow.name == @create_attrs["name"]

        :ok
      end)

      conn = post(conn, Routes.flow_path(conn, :create, @realm), data: @create_attrs)
      assert %{"name" => name} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.flow_path(conn, :show, @realm, name))

      assert %{
               "name" => name
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.flow_path(conn, :create, @realm), data: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete flow" do
    setup [
      :set_mox_from_context,
      :setup_public_key_provider,
      :cleanup_flows,
      :populate_pipelines,
      :create_flow,
      :verify_on_exit!
    ]

    test "deletes chosen flow", %{conn: conn, flow: flow} do
      FlowsStorageMock
      |> expect(:delete_flow, fn realm, name ->
        assert realm == @realm
        assert name == flow.name

        :ok
      end)

      conn = delete(conn, Routes.flow_path(conn, :delete, @realm, flow))
      assert response(conn, 204)

      conn = get(conn, Routes.flow_path(conn, :show, @realm, flow))
      assert response(conn, 404)
    end
  end

  defp create_flow(_) do
    flow = fixture(:flow)
    {:ok, flow: flow}
  end

  defp cleanup_flows(_context) do
    on_exit(fn ->
      DynamicSupervisor.which_children(FlowsSupervisor)
      |> Enum.each(fn {_, pid, _, _} ->
        DynamicSupervisor.terminate_child(FlowsSupervisor, pid)
      end)

      # Wait a moment to ensure they all go down
      :timer.sleep(100)
    end)
  end

  defp populate_pipelines(context) do
    set_mox_global(context)

    PipelinesStorageMock
    |> stub(:fetch_pipeline, fn
      @realm, "test" ->
        alias Astarte.Flow.Pipelines.Pipeline

        source = "random_source.key(${$.config.key}).min(0).max(100)"
        pipeline = %Pipeline{name: "test", source: source, description: ""}

        {:ok, pipeline}

      @realm, "nonexisting" ->
        {:error, :not_found}
    end)

    :ok
  end

  defp setup_public_key_provider(_context) do
    stub_with(PublicKeyProviderMock, Astarte.Flow.AuthTestHelper)

    :ok
  end
end
