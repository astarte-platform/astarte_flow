#
# This file is part of Astarte.
#
# Copyright 2021 Ispirata Srl
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

defmodule Astarte.Flow.Blocks.MqttSink do
  @moduledoc """
  An Astarte Flow consumer that publishes MQTT messages from incoming Flow
  messages.

  This block supports only incoming messages with type `:binary`, so
  serialization to binary format must be handled in a separate block before the
  message arrives here.

  When a message is received, `MqttSink` generates an MQTT publish with this conversion process:
    * `key` is used as topic
    * `data` is used as payload
    * `type` must always be `:binary`, messages without a binary type are discarded
  """

  use GenStage

  require Logger
  alias Astarte.Flow.Message

  defmodule State do
    @moduledoc false

    defstruct [
      :mqtt_connection,
      :client_id,
      :publish_qos
    ]
  end

  @doc """
  Starts the `MqttSource`.

  ## Options
  * `broker_url` (required): the URL of the broker the source will connect to. The transport will
  be deduced by the URL: if `mqtts://` is used, SSL transport will be used, if `mqtt://` is
  used, TCP transport will be used.
  * `client_id`: the client id used to connect. Defaults to a random string.
  * `username`: username used to authenticate to the broker.
  * `password`: password used to authenticate to the broker.
  * `ca_cert_pem`: a PEM encoded CA certificate. If not provided, the default CA trust store
  provided by `:certifi` will be used.
  * `client_cert_pem`: a PEM encoded client certificate, used for mutual SSL authentication. If
  this is provided, also `private_key_pem` must be provided.
  * `private_key_pem`: a PEM encoded private key, used for mutual SSL authentication. If this
  is provided, also `client_cert_pem` must be provided.
  * `ignore_ssl_errors`: if true, accept invalid certificates (e.g. self-signed) when using SSL.
  * `qos`: the qos that will be used to publish messages. Defaults to 0.
  """
  @spec start_link(opts) :: GenServer.on_start()
        when opts: [opt],
             opt:
               {:broker_url, String.t()}
               | {:client_id, String.t()}
               | {:username, String.t()}
               | {:password, String.t()}
               | {:ignore_ssl_errors, boolean()}
               | {:qos, Tortoise.qos()}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # GenStage callbacks

  @impl true
  def init(opts) do
    with {:ok, tortoise_opts} <- build_tortoise_opts(opts),
         client_id = Keyword.fetch!(tortoise_opts, :client_id),
         {:ok, qos} <- fetch_qos(opts),
         {:ok, pid} <- Tortoise.Connection.start_link(tortoise_opts) do
      state = %State{
        mqtt_connection: pid,
        client_id: client_id,
        publish_qos: qos
      }

      {:consumer, state}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_events(events, _from, state) do
    %State{
      client_id: client_id,
      publish_qos: qos
    } = state

    for %Message{key: topic, data: payload, type: :binary} <- events do
      Tortoise.publish(client_id, topic, payload, qos: qos)
    end

    {:noreply, [], state}
  end

  @impl true
  def handle_info({{Tortoise, _}, _ref, _response}, state) do
    # TODO: These are sent when QoS is 1 or 2, ignore these for now
    {:noreply, [], state}
  end

  defp fetch_qos(opts) do
    case Keyword.fetch(opts, :qos) do
      :error ->
        # Default, return 0
        {:ok, 0}

      {:ok, qos} when qos in [0, 1, 2] ->
        {:ok, qos}

      _ ->
        {:error, :invalid_qos}
    end
  end

  defp build_tortoise_opts(opts) do
    with {:url, {:ok, broker_url}} <- {:url, Keyword.fetch(opts, :broker_url)},
         client_id = Keyword.get_lazy(opts, :client_id, &random_client_id/0),
         {:ok, server} <- build_server(broker_url, opts) do
      base_opts = [
        client_id: client_id,
        broker_url: broker_url,
        server: server,
        handler: {Tortoise.Handler.Logger, []}
      ]

      additional_opts =
        Keyword.take(opts, [:username, :password])
        |> Enum.map(fn
          # Adapt :username option to Tortoise spelling (:user_name)
          {:username, username} ->
            {:user_name, username}

          {other, value} ->
            {other, value}
        end)

      {:ok, Keyword.merge(base_opts, additional_opts)}
    else
      {:url, _} ->
        {:error, :missing_broker_url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_server(broker_url, opts) do
    case URI.parse(broker_url) do
      %URI{scheme: "mqtts", host: host, port: port} when is_binary(host) ->
        build_ssl_server(host, port, opts)

      %URI{scheme: "mqtt", host: host, port: port} when is_binary(host) ->
        build_tcp_server(host, port)

      _ ->
        _ = Logger.warning("Can't parse broker url: #{inspect(broker_url)}")
        {:error, :invalid_broker_url}
    end
  end

  defp build_ssl_server(host, port, opts) do
    with {:ok, cert_opts} <- build_cert_opts(opts) do
      # This is needed to support wildcard certificates
      hostname_match_fun = :public_key.pkix_verify_hostname_match_fun(:https)

      verify =
        if Keyword.get(opts, :ignore_ssl_errors) do
          :verify_none
        else
          :verify_peer
        end

      server_opts =
        [
          host: host,
          port: port || 8883,
          verify: verify,
          customize_hostname_check: [match_fun: hostname_match_fun],
          depth: 10
        ] ++ cert_opts

      {:ok, {Tortoise.Transport.SSL, server_opts}}
    end
  end

  defp build_cert_opts(opts) do
    with {:ok, ca_opts} <- build_ca_opts(opts),
         {:ok, mutual_auth_opts} <- build_mutual_auth_opts(opts) do
      {:ok, ca_opts ++ mutual_auth_opts}
    end
  end

  defp build_ca_opts(opts) do
    with {:ok, ca_pem} <- Keyword.fetch(opts, :ca_cert_pem),
         {:ok, ca} <- X509.Certificate.from_pem(ca_pem) do
      ca_der = X509.Certificate.to_der(ca)

      {:ok, [cacerts: [ca_der]]}
    else
      :error ->
        # No explicit CA cert, use certifi
        {:ok, [cacertfile: :certifi.cacertfile()]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_mutual_auth_opts(opts) do
    has_private_key = Keyword.has_key?(opts, :private_key_pem)
    has_cert = Keyword.has_key?(opts, :client_cert_pem)

    with {:has_key_and_cert, true, true} <- {:has_key_and_cert, has_private_key, has_cert},
         key_pem = Keyword.fetch!(opts, :private_key_pem),
         {:ok, key} <- X509.PrivateKey.from_pem(key_pem),
         cert_pem = Keyword.fetch!(opts, :client_cert_pem),
         {:ok, cert} <- X509.Certificate.from_pem(cert_pem) do
      # Tortoise expects the key in the format {key_type, key_der}, the
      # key type is contained in the Erlang native key format in the first
      # tuple field
      key_type = elem(key, 0)
      key_der = X509.PrivateKey.to_der(key)

      cert_der = X509.Certificate.to_der(cert)

      {:ok, [key: {key_type, key_der}, cert: cert_der]}
    else
      {:has_key_and_cert, false, false} ->
        # Both key and cert are missing so no mutual SSL auth, return empty opts
        {:ok, []}

      {:has_key_and_cert, true, false} ->
        {:error, :missing_client_cert_pem}

      {:has_key_and_cert, false, true} ->
        {:error, :missing_private_key_pem}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_tcp_server(host, port) do
    server_opts = [
      host: host,
      port: port || 1883
    ]

    {:ok, {Tortoise.Transport.Tcp, server_opts}}
  end

  defp random_client_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end
end
