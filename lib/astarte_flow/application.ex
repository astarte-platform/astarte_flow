#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.Flow.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Astarte.Flow.Config

  alias Astarte.Flow.Auth.AstartePublicKeyProvider
  alias Astarte.Flow.Auth.FilesystemPublicKeyProvider

  def start(_type, _args) do
    Config.validate!()

    # List all child processes to be supervised
    children =
      [
        {Registry, keys: :unique, name: Astarte.Flow.Flows.Registry},
        {Registry, keys: :duplicate, name: Astarte.Flow.Flows.RealmRegistry},
        Astarte.Flow.Pipelines.DETSStorage,
        Astarte.Flow.Flows.DETSStorage,
        {DynamicSupervisor, strategy: :one_for_one, name: Astarte.Flow.Flows.Supervisor},
        Astarte.Flow.Blocks.DynamicVirtualDevicePool.DETSCredentialsStorage,
        {DynamicSupervisor, strategy: :one_for_one, name: Astarte.Flow.VirtualDevicesSupervisor},
        Astarte.Flow.RestoreFlowsTask,
        Astarte.FlowWeb.Endpoint
      ]
      |> setup_public_key_provider()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Astarte.Flow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Astarte.FlowWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp setup_public_key_provider(children) do
    if Config.disable_authentication!() do
      children
    else
      case Config.realm_public_key_provider() do
        {:ok, AstartePublicKeyProvider} ->
          # We have to connect to Astarte, so we need Xandra
          nodes = Config.xandra_nodes!()

          if nodes == nil do
            raise "CASSANDRA_NODES is mandatory with astarte provider"
          end

          # Add Xandra to the started children
          [{Xandra.Cluster, nodes: nodes, name: :xandra} | children]

        {:ok, FilesystemPublicKeyProvider} ->
          # Validate that the directory is set
          dir = Config.realm_public_keys_dir!()

          if dir == nil do
            raise "FLOW_REALM_PUBLIC_KEYS_DIR is mandatory with filesystem provider"
          end

          children

        {:ok, nil} ->
          raise "FLOW_REALM_PUBLIC_KEY_PROVIDER must be one of: astarte, filesystem"

        {:ok, _other} ->
          children
      end
    end
  end
end
