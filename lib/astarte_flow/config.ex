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

defmodule Astarte.Flow.Config do
  use Skogsra

  alias Astarte.Flow.Auth.RealmPublicKeyProvider
  alias Astarte.Flow.Config.XandraNodes

  @envdoc "Name of the Kubernetes instance of astarte which Flow will connect to"
  app_env :astarte_instance, :astarte_flow, :astarte_instance,
    os_env: "FLOW_ASTARTE_INSTANCE",
    default: "astarte"

  @envdoc "Kubernetes namespace where Flow will deploy its containers"
  app_env :target_namespace, :astarte_flow, :target_namespace,
    os_env: "FLOW_TARGET_NAMESPACE",
    default: "astarte"

  @envdoc "The directory where Flow will persist its dets tables"
  app_env :persistency_dir, :astarte_flow, :persistency_dir,
    os_env: "FLOW_PERSISTENCY_DIR",
    default: ""

  @envdoc "Default RabbitMQ connection host"
  app_env :default_amqp_connection_host, :astarte_flow, :default_amqp_connection_host,
    os_env: "FLOW_DEFAULT_AMQP_CONNECTION_HOST",
    default: "astarte"

  @envdoc "Default RabbitMQ connection port"
  app_env :default_amqp_connection_port, :astarte_flow, :default_amqp_connection_port,
    os_env: "FLOW_DEFAULT_AMQP_CONNECTION_PORT",
    type: :integer,
    default: 5672

  @envdoc "Default RabbitMQ connection username"
  app_env :default_amqp_connection_username, :astarte_flow, :default_amqp_connection_username,
    os_env: "FLOW_DEFAULT_AMQP_CONNECTION_USERNAME",
    default: "astarte"

  @envdoc "Default RabbitMQ connection password"
  app_env :default_amqp_connection_password, :astarte_flow, :default_amqp_connection_password,
    os_env: "FLOW_DEFAULT_AMQP_CONNECTION_PASSWORD",
    default: "astarte"

  @envdoc "Default RabbitMQ connection virtual host"
  app_env :default_amqp_connection_virtual_host,
          :astarte_flow,
          :default_amqp_connection_virtual_host,
          os_env: "FLOW_DEFAULT_AMQP_CONNECTION_HOST",
          default: "/"

  @envdoc """
  Disables the authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA
  IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING."
  """
  app_env :disable_authentication, :astarte_flow, :disable_authentication,
    os_env: "FLOW_DISABLE_AUTHENTICATION",
    type: :boolean,
    default: false

  app_env :realm_public_key_provider, :astarte_flow, :realm_public_key_provider,
    os_env: "FLOW_REALM_PUBLIC_KEY_PROVIDER",
    type: RealmPublicKeyProvider

  app_env :realm_public_keys_dir, :astarte_flow, :realm_public_keys_dir,
    os_env: "FLOW_REALM_PUBLIC_KEYS_DIR"

  app_env :xandra_nodes, :astarte_flow, :xandra_nodes,
    os_env: "CASSANDRA_NODES",
    type: XandraNodes

  @doc "Returns the default amqp connection parameters"
  def default_amqp_connection! do
    [
      host: default_amqp_connection_host!(),
      port: default_amqp_connection_port!(),
      username: default_amqp_connection_username!(),
      password: default_amqp_connection_password!(),
      virtual_host: default_amqp_connection_virtual_host!()
    ]
  end
end
