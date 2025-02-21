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

defmodule Astarte.FlowWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use Astarte.FlowWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: Astarte.FlowWeb.ChangesetJSON)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: Astarte.FlowWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :pipeline_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: Astarte.FlowWeb.ErrorJSON)
    |> render(:"404_pipeline_not_found")
  end

  def call(conn, {:error, :already_existing_pipeline}) do
    conn
    |> put_status(:conflict)
    |> put_view(json: Astarte.FlowWeb.ErrorJSON)
    |> render(:"409_existing_pipeline")
  end

  def call(conn, {:error, failures: failures}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(:"422_failed_pipeline_instantiation", error: failures)
  end

  def call(conn, {:error, :already_existing_block}) do
    conn
    |> put_status(:conflict)
    |> put_view(json: Astarte.FlowWeb.ErrorJSON)
    |> render(:"409_existing_block")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: Astarte.FlowWeb.ErrorJSON)
    |> render(:"401")
  end

  # This is called when no JWT token is present
  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: Astarte.FlowWeb.ErrorJSON)
    |> render(:"401")
  end

  # In all other cases, we reply with 403
  def auth_error(conn, _reason, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: Astarte.FlowWeb.ErrorJSON)
    |> render(:"403")
  end
end
