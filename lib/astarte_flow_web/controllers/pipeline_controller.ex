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

defmodule Astarte.FlowWeb.PipelineController do
  use Astarte.FlowWeb, :controller

  alias Astarte.Flow.Pipelines

  action_fallback Astarte.FlowWeb.FallbackController

  def index(conn, %{"realm" => realm}) do
    pipelines = Pipelines.list_pipelines(realm)
    render(conn, :index, pipelines: pipelines)
  end

  def show(conn, %{"realm" => realm, "name" => name}) do
    with {:ok, pipeline} <- Pipelines.get_pipeline(realm, name) do
      render(conn, :show, pipeline: pipeline)
    end
  end

  def create(conn, %{"realm" => realm, "data" => params}) do
    with {:ok, pipeline} <- Pipelines.create_pipeline(realm, params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/v1/#{realm}/pipelines/#{pipeline}")
      |> render(:show, pipeline: pipeline)
    end
  end

  def delete(conn, %{"realm" => realm, "name" => name}) do
    with {:ok, _pipeline} <- Pipelines.get_pipeline(realm, name),
         :ok <- Pipelines.delete_pipeline(realm, name) do
      send_resp(conn, :no_content, "")
    end
  end
end
