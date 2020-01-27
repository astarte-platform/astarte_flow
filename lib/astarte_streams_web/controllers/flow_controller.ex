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

defmodule Astarte.StreamsWeb.FlowController do
  use Astarte.StreamsWeb, :controller

  alias Astarte.Streams.Flows
  alias Astarte.Streams.Flows.Flow

  action_fallback Astarte.StreamsWeb.FallbackController

  def index(conn, _params) do
    flows = Flows.list_flows()
    render(conn, "index.json", flows: flows)
  end

  def create(conn, %{"flow" => flow_params}) do
    with {:ok, %Flow{} = flow} <- Flows.create_flow(flow_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.flow_path(conn, :show, flow))
      |> render("show.json", flow: flow)
    end
  end

  def show(conn, %{"id" => id}) do
    flow = Flows.get_flow!(id)
    render(conn, "show.json", flow: flow)
  end

  def update(conn, %{"id" => id, "flow" => flow_params}) do
    flow = Flows.get_flow!(id)

    with {:ok, %Flow{} = flow} <- Flows.update_flow(flow, flow_params) do
      render(conn, "show.json", flow: flow)
    end
  end

  def delete(conn, %{"id" => id}) do
    flow = Flows.get_flow!(id)

    with {:ok, %Flow{}} <- Flows.delete_flow(flow) do
      send_resp(conn, :no_content, "")
    end
  end
end
