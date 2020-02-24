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

defmodule Astarte.Flow.K8s do
  require Logger

  alias K8s.Client
  alias K8s.Conn

  @api_version "api.astarte-platform.org/v1alpha1"
  @flow_kind "Flow"

  defmodule ContainerBlock do
    @enforce_keys [
      :block_id,
      :image,
      :config,
      :exchange_routing_key,
      :queue,
      :cpu_limit,
      :memory_limit,
      # TODO: make requests optional
      :cpu_requests,
      :memory_requests
    ]

    defstruct [
      :block_id,
      :image,
      :config,
      :exchange_routing_key,
      :queue,
      :cpu_limit,
      :memory_limit,
      :cpu_requests,
      :memory_requests
    ]

    @type t() :: %__MODULE__{
            block_id: String.t(),
            image: String.t(),
            exchange_routing_key: String.t(),
            queue: String.t(),
            cpu_limit: String.t(),
            memory_limit: String.t(),
            cpu_requests: String.t(),
            memory_requests: String.t()
          }
  end

  @spec delete_flow(String.t()) :: {:ok, reference() | map()} | {:error, atom() | binary()}
  def delete_flow(flow_name) do
    with {:ok, conn} <- Conn.lookup(:default) do
      namespace = Application.fetch_env!(:astarte_flow, :target_namespace)

      Client.delete(@api_version, @flow_kind, namespace: namespace, name: flow_name)
      |> Client.run(conn)
    end
  end

  @spec try_delete_flow(String.t()) :: :ok | {:error, atom() | binary()}
  def try_delete_flow(flow_name) do
    case delete_flow(flow_name) do
      {:ok, _result} -> :ok
      {:error, :not_found} -> :ok
      any -> any
    end
  end

  @spec create_flow(String.t(), String.t(), list(ContainerBlock.t())) ::
          :ok | {:error, atom() | binary()}
  def create_flow(realm, flow_name, blocks) do
    with :ok <- try_delete_flow(flow_name),
         resource = flow_custom_resource(realm, flow_name, blocks),
         create_operation = Client.create(resource),
         {:ok, conn} <- Conn.lookup(:default),
         {:ok, _result} <- Client.run(create_operation, conn) do
      :ok
    end
  end

  def flow_status(flow_name) do
    namespace = Application.fetch_env!(:astarte_flow, :target_namespace)
    op = K8s.Client.get(@api_version, @flow_kind, namespace: namespace, name: flow_name)

    with {:ok, conn} <- Conn.lookup(:default),
         {:ok, result} <- Client.run(op, conn) do
      {:ok, result["status"]["state"]}
    end
  end

  @spec block_custom_resource(ContainerBlock.t()) :: map()
  def block_custom_resource(block) do
    %ContainerBlock{
      block_id: block_id,
      config: config,
      image: image,
      cpu_limit: cpu_limit,
      memory_limit: memory_limit,
      cpu_requests: cpu_requests,
      memory_requests: memory_requests
    } = block

    rabbitmq_map = build_rabbitmq_map(block)

    %{
      "config" => Jason.encode!(config),
      "environment" => [],
      "id" => block_id,
      "image" => image,
      "resources" => %{
        "limits" => %{
          "cpu" => cpu_limit,
          "memory" => memory_limit
        },
        "requests" => %{
          "cpu" => cpu_requests,
          "memory" => memory_requests
        }
      },
      "workers" => [
        %{
          "dataProvider" => %{
            "rabbitmq" => rabbitmq_map
          },
          "id" => "worker-0"
        }
      ]
    }
  end

  defp build_rabbitmq_map(%ContainerBlock{exchange_routing_key: nil, queue: queue}) do
    %{
      "queues" => [queue]
    }
  end

  defp build_rabbitmq_map(%ContainerBlock{exchange_routing_key: exchange_routing_key, queue: nil}) do
    %{
      "exchange" => %{
        "name" => "",
        "routingKey" => exchange_routing_key
      }
    }
  end

  defp build_rabbitmq_map(block) do
    %ContainerBlock{
      exchange_routing_key: exchange_routing_key,
      queue: queue
    } = block

    %{
      "exchange" => %{
        "name" => "",
        "routingKey" => exchange_routing_key
      },
      "queues" => [queue]
    }
  end

  @spec flow_custom_resource(String.t(), String.t(), list(ContainerBlock.t())) :: map()
  def flow_custom_resource(realm, flow_name, blocks) do
    namespace = Application.fetch_env!(:astarte_flow, :target_namespace)
    astarte_name = Application.fetch_env!(:astarte_flow, :astarte_instance)

    %{
      "apiVersion" => @api_version,
      "kind" => @flow_kind,
      "metadata" => %{"name" => flow_name, "namespace" => namespace},
      "spec" => %{
        "astarte" => %{"name" => astarte_name},
        "astarteRealm" => realm,
        "blocks" => Enum.map(blocks, &block_custom_resource/1)
      }
    }
  end
end
