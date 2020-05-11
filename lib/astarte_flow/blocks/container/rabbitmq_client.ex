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

defmodule Astarte.Flow.Blocks.Container.RabbitMQClient do
  alias AMQP.{
    Basic,
    Channel,
    Connection,
    Queue
  }

  @behaviour Astarte.Flow.Blocks.Container.AMQPClient
  @timeout 10_000

  @doc """
  Initialize the AMQP client config
  """
  @spec generate_config(opts :: keyword) :: {:ok, config :: map()} | {:error, reason :: term()}
  @impl true
  def generate_config(opts) do
    # TODO: validate opts

    queue_prefix = Keyword.fetch!(opts, :queue_prefix)
    connection = Keyword.get(opts, :connection, [])
    prefetch_count = Keyword.get(opts, :prefetch_count, 100)

    config = %{connection: connection, queue_prefix: queue_prefix, prefetch_count: prefetch_count}

    {:ok, config}
  end

  @doc """
  Initialize the AMQP channel
  """
  @spec setup(config :: map, type :: :producer | :consumer | :producer_consumer) ::
          {:ok, map()} | {:error, reason :: term()}
  @impl true
  def setup(config, type) do
    queue_prefix = config.queue_prefix
    # We add a timeout so the block doesn't wait too much for the connection
    conn_opts = Keyword.put(config.connection, :connection_timeout, @timeout)

    with {:ok, conn} <- Connection.open(conn_opts),
         {:ok, chan} <- Channel.open(conn),
         :ok <- Basic.qos(chan, prefetch_count: config.prefetch_count),
         {:ok, queues_info} <- queues_setup(chan, queue_prefix, type) do
      {:ok, Map.put(queues_info, :channel, chan)}
    end
  end

  defp queues_setup(chan, queue_prefix, :producer_consumer) do
    # TODO: we assume a single outbound/inbound queue for now, publishing on the default
    # exchange with the queue name as routing key.
    with {:ok, %{queue: outbound_queue}} <-
           Queue.declare(chan, queue_prefix <> "-outbound", auto_delete: true),
         {:ok, %{queue: inbound_queue}} <-
           Queue.declare(chan, queue_prefix <> "-inbound", auto_delete: true) do
      {:ok,
       %{
         outbound_routing_key: outbound_queue,
         outbound_queues: [outbound_queue],
         inbound_routing_key: inbound_queue,
         inbound_queues: [inbound_queue]
       }}
    end
  end

  defp queues_setup(chan, queue_prefix, :producer) do
    # Producer, so only inbound queue
    with {:ok, %{queue: inbound_queue}} <-
           Queue.declare(chan, queue_prefix <> "-inbound", auto_delete: true) do
      {:ok,
       %{
         outbound_routing_key: nil,
         outbound_queues: [],
         inbound_routing_key: inbound_queue,
         inbound_queues: [inbound_queue]
       }}
    end
  end

  defp queues_setup(chan, queue_prefix, :consumer) do
    # Consumer, so only outbound queue

    with {:ok, %{queue: outbound_queue}} <-
           Queue.declare(chan, queue_prefix <> "-outbound", auto_delete: true) do
      {:ok,
       %{
         outbound_routing_key: outbound_queue,
         outbound_queues: [outbound_queue],
         inbound_routing_key: nil,
         inbound_queues: []
       }}
    end
  end

  @impl true
  def publish(channel, exchange, routing_key, payload, opts \\ []) do
    Basic.publish(channel, exchange, routing_key, payload, opts)
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
  def consume(channel, queue) do
    {:ok, consumer_tag} = Basic.consume(channel, queue)
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
