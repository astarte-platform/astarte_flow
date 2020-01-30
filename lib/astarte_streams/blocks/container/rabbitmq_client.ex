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

defmodule Astarte.Streams.Blocks.Container.RabbitMQClient do
  alias AMQP.{
    Basic,
    Channel,
    Connection,
    Queue
  }

  @behaviour Astarte.Streams.Blocks.Container.AMQPClient

  @doc """
  Initialize the AMQP client config
  """
  @spec generate_config(opts :: keyword) :: {:ok, config :: map()} | {:error, reason :: term()}
  @impl true
  def generate_config(opts) do
    # TODO: validate opts

    connection = Keyword.get(opts, :connection, [])

    config = %{connection: connection}

    {:ok, config}
  end

  @doc """
  Initialize the AMQP channel
  """
  @spec setup(config :: map) ::
          {:ok, map()} | {:error, reason :: term()}
  @impl true
  def setup(config) do
    with {:ok, conn} <- Connection.open(config.connection),
         {:ok, chan} <- Channel.open(conn),
         # TODO: we assume a single outbound/inbound queue for now, publishing on the default
         # exchange with the queue name as routing key.
         {:ok, %{queue: outbound_queue}} <- Queue.declare(chan, "", auto_delete: true),
         {:ok, %{queue: inbound_queue}} <- Queue.declare(chan, "", auto_delete: true) do
      ret = %{
        channel: chan,
        outbound_queues: [outbound_queue],
        inbound_queues: [inbound_queue]
      }

      {:ok, ret}
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
end
