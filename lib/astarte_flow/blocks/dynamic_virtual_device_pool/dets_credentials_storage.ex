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

defmodule Astarte.Flow.Blocks.DynamicVirtualDevicePool.DETSCredentialsStorage do
  use GenServer
  @behaviour Astarte.Flow.Blocks.DynamicVirtualDevicePool.CredentialsStorage

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def fetch_credentials_secret(realm, device_id) do
    GenServer.call(__MODULE__, {:fetch_credentials_secret, realm, device_id})
  end

  @impl true
  def store_credentials_secret(realm, device_id, credentials_secret) do
    GenServer.call(__MODULE__, {:store_credentials_secret, realm, device_id, credentials_secret})
  end

  @impl true
  def init(_args) do
    file =
      Application.get_env(:astarte_flow, :persistency_dir, "")
      |> Path.expand()
      |> Path.join("credentials_secret")
      |> to_charlist()

    case :dets.open_file(:credentials_storage, type: :set, file: file) do
      {:ok, table} ->
        {:ok, table}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:fetch_credentials_secret, realm, device_id}, _from, table) do
    case :dets.lookup(table, {realm, device_id}) do
      [{{^realm, ^device_id}, credentials_secret}] ->
        {:reply, {:ok, credentials_secret}, table}

      [] ->
        {:reply, :error, table}
    end
  end

  @impl true
  def handle_call({:store_credentials_secret, realm, device_id, credentials_secret}, _from, table) do
    reply = :dets.insert(table, {{realm, device_id}, credentials_secret})

    {:reply, reply, table}
  end
end
