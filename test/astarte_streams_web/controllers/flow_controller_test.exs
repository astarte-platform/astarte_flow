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

defmodule Astarte.StreamsWeb.FlowControllerTest do
  use Astarte.StreamsWeb.ConnCase

  alias Astarte.Streams.Flows
  alias Astarte.Streams.Flows.Flow

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  def fixture(:flow) do
    {:ok, flow} = Flows.create_flow(@create_attrs)
    flow
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all flows", %{conn: conn} do
      conn = get(conn, Routes.flow_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create flow" do
    test "renders flow when data is valid", %{conn: conn} do
      conn = post(conn, Routes.flow_path(conn, :create), flow: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.flow_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.flow_path(conn, :create), flow: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update flow" do
    setup [:create_flow]

    test "renders flow when data is valid", %{conn: conn, flow: %Flow{id: id} = flow} do
      conn = put(conn, Routes.flow_path(conn, :update, flow), flow: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.flow_path(conn, :show, id))

      assert %{
               "id" => id
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, flow: flow} do
      conn = put(conn, Routes.flow_path(conn, :update, flow), flow: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete flow" do
    setup [:create_flow]

    test "deletes chosen flow", %{conn: conn, flow: flow} do
      conn = delete(conn, Routes.flow_path(conn, :delete, flow))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.flow_path(conn, :show, flow))
      end
    end
  end

  defp create_flow(_) do
    flow = fixture(:flow)
    {:ok, flow: flow}
  end
end
