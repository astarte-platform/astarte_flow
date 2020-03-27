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

defmodule Astarte.FlowWeb.AuthTest do
  use Astarte.FlowWeb.ConnCase

  alias Astarte.Flow.AuthTestHelper

  import Mox

  @realm "test"

  setup do
    stub(PipelinesStorageMock, :list_pipelines, fn _realm -> [] end)
    :ok
  end

  describe "connection without JWT token" do
    setup [:setup_unauthorized_conn, :stub_public_key_provider]

    test "returns 401 when accessing pipelines", %{conn: conn} do
      conn = get(conn, Routes.pipeline_path(conn, :index, @realm))
      assert json_response(conn, 401)["errors"] != nil
    end

    test "returns 401 when accessing flows", %{conn: conn} do
      conn = get(conn, Routes.flow_path(conn, :index, @realm))
      assert json_response(conn, 401)["errors"] != nil
    end
  end

  describe "connection with authorization token allowing POST" do
    setup [:setup_post_authorized_conn, :stub_public_key_provider]

    test "returns 403 when GETting pipelines", %{conn: conn} do
      conn = get(conn, Routes.pipeline_path(conn, :index, @realm))
      assert json_response(conn, 403)["errors"] != nil
    end

    test "returns 403 when GETting flows", %{conn: conn} do
      conn = get(conn, Routes.flow_path(conn, :index, @realm))
      assert json_response(conn, 403)["errors"] != nil
    end
  end

  describe "connection with authorization token allowing GET" do
    setup [:setup_get_authorized_conn, :stub_public_key_provider]

    test "succesfully GETs pipelines", %{conn: conn} do
      conn = get(conn, Routes.pipeline_path(conn, :index, @realm))
      assert json_response(conn, 200)
    end

    test "succesfully GETs flows", %{conn: conn} do
      conn = get(conn, Routes.flow_path(conn, :index, @realm))
      assert json_response(conn, 200)
    end
  end

  describe "connection with authorization token allowing all verbs on pipelines" do
    setup [:setup_pipelines_authorized_conn, :stub_public_key_provider]

    test "succesfully GETs pipelines", %{conn: conn} do
      conn = get(conn, Routes.pipeline_path(conn, :index, @realm))
      assert json_response(conn, 200)
    end

    test "returns 403 when GETting flows", %{conn: conn} do
      conn = get(conn, Routes.flow_path(conn, :index, @realm))
      assert json_response(conn, 403)["errors"] != nil
    end
  end

  describe "connection with all access authorization" do
    setup [:setup_all_access_authorized_conn, :stub_public_key_provider]

    test "succesfully GETs pipelines", %{conn: conn} do
      conn = get(conn, Routes.pipeline_path(conn, :index, @realm))
      assert json_response(conn, 200)
    end

    test "succesfully GETs flows", %{conn: conn} do
      conn = get(conn, Routes.flow_path(conn, :index, @realm))
      assert json_response(conn, 200)
    end
  end

  defp setup_post_authorized_conn(%{conn: conn}) do
    setup_conn_with_claim(conn, "POST::.*")
  end

  defp setup_get_authorized_conn(%{conn: conn}) do
    setup_conn_with_claim(conn, "GET::.*")
  end

  defp setup_pipelines_authorized_conn(%{conn: conn}) do
    setup_conn_with_claim(conn, ".*::pipelines.*")
  end

  defp setup_all_access_authorized_conn(%{conn: conn}) do
    setup_conn_with_claim(conn, ".*::.*")
  end

  defp setup_conn_with_claim(conn, claim) do
    jwt = AuthTestHelper.gen_jwt_token([claim])

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer " <> jwt)

    {:ok, conn: conn}
  end

  defp setup_unauthorized_conn(%{conn: conn}) do
    conn =
      conn
      |> put_req_header("accept", "application/json")

    {:ok, conn: conn}
  end

  defp stub_public_key_provider(_context) do
    stub_with(PublicKeyProviderMock, Astarte.Flow.AuthTestHelper)

    :ok
  end
end
