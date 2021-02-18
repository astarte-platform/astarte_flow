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
        verify =
          if Keyword.get(opts, :ignore_ssl_errors) do
            :verify_none
          else
            :verify_peer
          end

        opts = [
          host: host,
          port: port || 8883,
          cacertfile: :certifi.cacertfile(),
          verify: verify,
          depth: 10
        ]

        {:ok, {Tortoise.Transport.SSL, opts}}

      %URI{scheme: "mqtt", host: host, port: port} when is_binary(host) ->
        opts = [
          host: host,
          port: port || 1883
        ]

        {:ok, {Tortoise.Transport.Tcp, opts}}

      _ ->
        _ = Logger.warn("Can't parse broker url: #{inspect(broker_url)}")
        {:error, :invalid_broker_url}
    end
  end

  defp random_client_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end
end
