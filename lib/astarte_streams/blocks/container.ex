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

defmodule Astarte.Streams.Blocks.Container do
  @moduledoc """
  This is a producer_consumer block that sends messages to a Docker container.

  Messages are sent and received via AMQP.

  The block will manage the creation of the Container in a Kubernetes cluster using
  the Astarte Kubernetes Operator.
  """

  use GenStage

  require Logger

  alias Astarte.Streams.Blocks.Container.RabbitMQClient
  alias Astarte.Streams.Message

  @retry_timeout_ms 10_000

  defmodule State do
    @moduledoc false

    defstruct [
      :amqp_client,
      :channel,
      :config,
      :channel_ref,
      :conn_ref,
      :image,
      outbound_queues: [],
      inbound_queues: []
    ]
  end

  @doc """
  Starts the `Container` block.

  ## Options

  * `:image` (required) - The tag of the docker image that will be used by the block.
  * `:connection` - A keyword list containing the options that will be passed to
    `AMQP.Connection.open/1`. Defaults to `[]`.
  * `:amqp_client` - A module that implements the
    `Astarte.Streams.Blocks.Container.AMQPClient` behaviour and that will
    be used to connect to AMQP. Defaults to
    `Astarte.Streams.Blocks.Container.RabbitMQClient`
  """
  @spec start_link(options) :: GenServer.on_start()
        when options: [option],
             option:
               {:image, String.t()}
               | {:connection, keyword()}
               | {:amqp_client, module()}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    image = Keyword.fetch!(opts, :image)
    amqp_client = Keyword.get(opts, :amqp_client, RabbitMQClient)

    with {:ok, config} <- amqp_client.generate_config(opts) do
      state = %State{
        amqp_client: amqp_client,
        channel: nil,
        config: config,
        channel_ref: nil,
        conn_ref: nil,
        image: image
      }

      send(self(), :connect)

      {:producer_consumer, state, dispatcher: GenStage.BroadcastDispatcher}
    else
      {:error, reason} ->
        {:stop, reason}

      _ ->
        {:stop, :init_error}
    end
  end

  @impl true
  def handle_events(events, _from, state) do
    %State{
      amqp_client: amqp_client,
      channel: channel,
      outbound_queues: outbound_queues
    } = state

    # TODO: this should check if the channel is currently up and accumulate
    # the events to publish them later otherwise
    for %Message{} = event <- events, routing_key <- outbound_queues do
      payload =
        Message.to_map(event)
        |> Jason.encode!()

      # TODO: for now we publish on the default exchange using outbound queue names
      # as routing key, to exploit default bindings
      amqp_client.publish(channel, "", routing_key, payload)
    end

    {:noreply, [], state}
  end

  @impl true
  def handle_info(:connect, state) do
    {:noreply, [], connect(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{conn_ref: ref} = state) do
    {:noreply, [], connect(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{channel_ref: ref} = state) do
    {:noreply, [], connect(state)}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
    {:noreply, [], state}
  end

  def handle_info({:basic_cancel, _}, state) do
    {:noreply, [], connect(state)}
  end

  def handle_info({:basic_cancel_ok, _}, state) do
    {:noreply, [], %{state | consumer_tag: nil}}
  end

  def handle_info({:basic_deliver, payload, meta}, state) do
    %State{amqp_client: amqp_client, channel: channel} = state

    with {:ok, decoded} <- Jason.decode(payload),
         {:ok, message} <- Message.from_map(decoded) do
      amqp_client.ack(channel, meta.delivery_tag)

      {:noreply, [message], state}
    else
      {:error, reason} ->
        Logger.warn("Invalid message received: #{inspect(reason)}",
          tag: "container_invalid_message"
        )

        amqp_client.reject(channel, meta.delivery_tag, requeue: false)
        {:noreply, [], state}
    end
  end

  defp connect(%State{amqp_client: amqp_client} = state) do
    case amqp_client.setup(state.config) do
      {:ok, %{channel: channel, outbound_queues: outbound_queues, inbound_queues: inbound_queues}} ->
        conn_ref = Process.monitor(channel.conn.pid)
        channel_ref = Process.monitor(channel.pid)

        for queue <- inbound_queues do
          amqp_client.consume(channel, queue)
        end

        %{
          state
          | channel: channel,
            outbound_queues: outbound_queues,
            inbound_queues: inbound_queues,
            conn_ref: conn_ref,
            channel_ref: channel_ref
        }

      {:error, reason} ->
        Logger.warn(
          "Cannot connect to RabbitMQ: #{inspect(reason)}. Retrying in #{@retry_timeout_ms} ms"
        )

        Process.send_after(self(), :connect, @retry_timeout_ms)

        state
    end
  end
end
