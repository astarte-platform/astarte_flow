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

defmodule Astarte.FlowWeb.FlowController do
  use Astarte.FlowWeb, :controller

  alias Astarte.Flow.Flows
  alias Astarte.Flow.Flows.Flow
  alias Astarte.Flow.PipelineBuilder

  action_fallback Astarte.FlowWeb.FallbackController

  def index(conn, %{"realm" => realm}) do
    flows = Flows.list_flows(realm)
    render(conn, :index, flows: flows)
  end

  def create(conn, %{"realm" => realm, "data" => flow_params}) do
    with {:ok, %Flow{} = flow} <- Flows.create_flow(realm, flow_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/v1/#{realm}/flows/#{flow}")
      |> render(:show, flow: flow)
    else
      {:error, %PipelineBuilder.Error{} = reason} ->
        render(conn, :error, error: reason)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def show(conn, %{"realm" => realm, "name" => name}) do
    with {:ok, flow} <- Flows.get_flow(realm, name) do
      render(conn, :show, flow: flow)
    end
  end

  def delete(conn, %{"realm" => realm, "name" => name}) do
    with {:ok, flow} <- Flows.get_flow(realm, name),
         :ok <- Flows.delete_flow(realm, flow) do
      send_resp(conn, :no_content, "")
    end
  end
end
