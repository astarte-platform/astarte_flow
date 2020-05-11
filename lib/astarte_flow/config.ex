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

  @envdoc "Enable SSL. If not specified SSL is disabled."
  app_env :default_amqp_connection_ssl_enabled,
          :astarte_flow,
          :default_amqp_connection_ssl_enabled,
          os_env: "FLOW_DEFAULT_AMQP_CONNECTION_SSL_ENABLED",
          type: :boolean,
          default: false

  @envdoc """
  Specifies the certificates of the root Certificate Authorities
  to be trusted. When not specified, the bundled cURL certificate
  bundle will be used.
  """

  app_env :default_amqp_connection_ssl_ca_file,
          :astarte_flow,
          :default_amqp_connection_ssl_ca_file,
          os_env: "FLOW_DEFAULT_AMQP_CONNECTION_SSL_CA_FILE",
          type: :binary

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env :default_amqp_connection_ssl_disable_sni,
          :astarte_flow,
          :default_amqp_connection_ssl_disable_sni,
          os_env: "FLOW_DEFAULT_AMQP_CONNECTION_SSL_DISABLE_SNI",
          type: :boolean,
          default: false

  @envdoc """
  Specify the hostname to be used in TLS Server Name Indication extension.
  If not specified, the amqp host will be used. This value is used only if
  Server Name Indication is enabled.
  """
  app_env :default_amqp_connection_ssl_custom_sni,
          :astarte_flow,
          :default_amqp_connection_ssl_custom_sni,
          os_env: "FLOW_DEFAULT_AMQP_CONNECTION_SSL_CUSTOM_SNI",
          type: :binary

  @envdoc "Default RabbitMQ prefetch count for each channel"
  app_env :default_amqp_prefetch_count, :astarte_flow, :default_amqp_prefetch_count,
    os_env: "FLOW_DEFAULT_AMQP_PREFETCH_COUNT",
    type: :integer,
    default: 100

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
  @type ssl_option ::
          {:cacertfile, String.t()}
          | {:verify, :verify_peer}
          | {:server_name_indication, :disable | charlist()}
  @type ssl_options :: :none | [ssl_option]
  @type options ::
          {:username, String.t()}
          | {:password, String.t()}
          | {:virtual_host, String.t()}
          | {:host, String.t()}
          | {:port, integer()}
          | {:ssl_options, ssl_options}
  @spec default_amqp_connection!() :: [options]
  def default_amqp_connection! do
    [
      host: default_amqp_connection_host!(),
      port: default_amqp_connection_port!(),
      username: default_amqp_connection_username!(),
      password: default_amqp_connection_password!(),
      virtual_host: default_amqp_connection_virtual_host!()
    ]
    |> populate_ssl_options()
  end

  defp populate_ssl_options(options) do
    if default_amqp_connection_ssl_enabled!() do
      ssl_options = build_ssl_options()
      Keyword.put(options, :ssl_options, ssl_options)
    else
      options
    end
  end

  defp build_ssl_options do
    [
      cacertfile: default_amqp_connection_ssl_ca_file!() || CAStore.file_path(),
      verify: :verify_peer
    ]
    |> populate_sni()
  end

  defp populate_sni(ssl_options) do
    if default_amqp_connection_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name = default_amqp_connection_ssl_custom_sni!() || default_amqp_connection_host!()
      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end
end
