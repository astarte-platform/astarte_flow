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

defmodule Astarte.Flow.Blocks.DeviceEventsProducer.RabbitMQClient do
  alias AMQP.{
    Basic,
    Channel,
    Connection,
    Queue
  }

  @behaviour Astarte.Flow.Blocks.DeviceEventsProducer.AMQPClient

  @doc """
  Initialize the AMQP client config
  """
  @spec generate_config(opts :: keyword) :: {:ok, config :: map()} | {:error, reason :: term()}
  @impl true
  def generate_config(opts) do
    # TODO: validate opts

    routing_key = Keyword.fetch!(opts, :routing_key)
    queue = Keyword.get(opts, :queue, "")
    connection = Keyword.get(opts, :connection, [])
    exchange = Keyword.get(opts, :exchange, "astarte_events")

    config = %{connection: connection, queue: queue, routing_key: routing_key, exchange: exchange}

    {:ok, config}
  end

  @doc """
  Initialize the AMQP channel
  """
  @spec setup_channel(config :: map) ::
          {:ok, chan :: AMQP.Channel.t()} | {:error, reason :: term()}
  @impl true
  def setup_channel(config) do
    with {:ok, conn} <- Connection.open(config.connection),
         {:ok, chan} <- Channel.open(conn),
         {:ok, _queue} <- Queue.declare(chan, config.queue, auto_delete: true),
         :ok <- Queue.bind(chan, config.queue, config.exchange, routing_key: config.routing_key) do
      {:ok, chan}
    end
  end

  @impl true
  def ack(channel, delivery_tag) do
    Basic.ack(channel, delivery_tag)
  end

  @impl true
  def reject(channel, delivery_tag, opts \\ []) do
    Basic.reject(channel, delivery_tag, opts)
  end

  @impl true
  def consume(channel, config) do
    {:ok, consumer_tag} = Basic.consume(channel, config.queue)
    consumer_tag
  end

  @impl true
  def close_connection(conn) do
    if Process.alive?(conn.pid) do
      Connection.close(conn)
    else
      :ok
    end
  end
end
