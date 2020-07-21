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

defmodule Astarte.FlowWeb.BlockController do
  use Astarte.FlowWeb, :controller

  alias Astarte.Flow.Blocks

  action_fallback Astarte.FlowWeb.FallbackController

  def index(conn, %{"realm" => realm}) do
    blocks = Blocks.list_blocks(realm)
    render(conn, "index.json", blocks: blocks)
  end

  def show(conn, %{"realm" => realm, "name" => name}) do
    with {:ok, block} <- Blocks.get_block(realm, name) do
      render(conn, "show.json", block: block)
    end
  end

  def create(conn, %{"realm" => realm, "data" => params}) do
    with {:ok, block} <- Blocks.create_block(realm, params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.block_path(conn, :show, realm, block))
      |> render("show.json", block: block)
    end
  end

  def delete(conn, %{"realm" => realm, "name" => name}) do
    with {:ok, _block} <- Blocks.get_block(realm, name),
         :ok <- Blocks.delete_block(realm, name) do
      send_resp(conn, :no_content, "")
    end
  end
end
