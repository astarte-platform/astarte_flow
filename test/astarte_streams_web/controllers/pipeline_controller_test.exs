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

  @realm "test"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all pipelines", %{conn: conn} do
      conn = get(conn, Routes.pipeline_path(conn, :index, @realm))
      assert json_response(conn, 200)["data"] == ["test"]
    end
  end

  describe "show" do
    test "renders pipeline", %{conn: conn} do
      conn = get(conn, Routes.pipeline_path(conn, :show, @realm, "test"))

      assert %{
               "name" => name,
               "source" => source
             } = json_response(conn, 200)["data"]

      assert source =~ "random_source"
    end

    test "renders 404 when not found", %{conn: conn} do
      conn = get(conn, Routes.pipeline_path(conn, :show, @realm, "notexising"))
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end
end
