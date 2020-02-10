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

  alias Astarte.Flow.Flows
  alias Astarte.Flow.Flows.Flow
  alias Astarte.Flow.Flows.Supervisor, as: FlowsSupervisor

  @realm "test"
  @create_attrs %{"name" => "test", "pipeline" => "test", "config" => %{"key" => "test"}}
  @invalid_attrs %{"name" => 42, "pipeline" => "test", "config" => %{"key" => "test"}}

  def fixture(:flow) do
    {:ok, flow} = Flows.create_flow(@realm, @create_attrs)
    flow
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all flows", %{conn: conn} do
      conn = get(conn, Routes.flow_path(conn, :index, @realm))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create flow" do
    setup [:cleanup_flows]

    test "renders flow when data is valid", %{conn: conn} do
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
    setup [:cleanup_flows, :create_flow]

    test "deletes chosen flow", %{conn: conn, flow: flow} do
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
end
