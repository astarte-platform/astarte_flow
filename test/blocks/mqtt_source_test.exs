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

defmodule Astarte.Streams.Blocks.MqttSourceTest do
  use ExUnit.Case

  alias Astarte.Streams.Blocks.MqttSource
  alias Astarte.Streams.Message

  @subscriptions ["#"]
  @broker_url "mqtt://notarealbrokerbutshouldworkfine"

  describe "start_link/1" do
    test "fails if broker_url is missing" do
      opts = [
        subscriptions: @subscriptions
      ]

      assert MqttSource.start_link(opts) == {:error, :missing_broker_url}
    end

    test "fails if broker_url is invalid" do
      opts = [
        subscriptions: @subscriptions,
        broker_url: "ftp://example.com"
      ]

      assert MqttSource.start_link(opts) == {:error, :invalid_broker_url}
    end

    test "fails if subscriptions are missing" do
      opts = [
        broker_url: @broker_url
      ]

      assert MqttSource.start_link(opts) == {:error, :missing_subscriptions}
    end

    test "fails if subscriptions are empty" do
      opts = [
        broker_url: @broker_url,
        subscriptions: []
      ]

      assert MqttSource.start_link(opts) == {:error, :empty_subscriptions}
    end

    test "succeeds with valid broker_url and subscriptions" do
      opts = [
        broker_url: @broker_url,
        subscriptions: @subscriptions
      ]

      {:ok, _pid} = MqttSource.start_link(opts)
    end
  end

  describe "incoming data" do
    setup do
      opts = [
        broker_url: @broker_url,
        subscriptions: @subscriptions
      ]

      {:ok, pid} = start_supervised({MqttSource, opts})

      {:ok, pid: pid}
    end

    test "gets delivered to consumers", %{pid: pid} do
      alias MqttSource.Handler

      stream = GenStage.stream([pid])

      handler_state = %{
        source_pid: pid,
        subtype: "application/octet-stream",
        broker_url: @broker_url
      }

      # Simulate the reception of mqtt messages by manually invoking the handler
      Handler.handle_message(["mytopic"], "payload", handler_state)
      Handler.handle_message(["another", "topic"], "another payload", handler_state)
      Handler.handle_message(["binary", "stuff"], <<1, 2, 3, 4>>, handler_state)

      assert [
               %Message{
                 key: "mytopic",
                 data: "payload",
                 type: :binary,
                 subtype: "application/octet-stream",
                 metadata: %{
                   "Astarte.Streams.Blocks.MqttSource.broker_url" => @broker_url
                 }
               },
               %Message{
                 key: "another/topic",
                 data: "another payload",
                 type: :binary,
                 subtype: "application/octet-stream",
                 metadata: %{
                   "Astarte.Streams.Blocks.MqttSource.broker_url" => @broker_url
                 }
               },
               %Message{
                 key: "binary/stuff",
                 data: <<1, 2, 3, 4>>,
                 type: :binary,
                 subtype: "application/octet-stream",
                 metadata: %{
                   "Astarte.Streams.Blocks.MqttSource.broker_url" => @broker_url
                 }
               }
             ] = Enum.take(stream, 3)
    end

    test "gets buffered and delivered when consumers subscribe", %{pid: pid} do
      alias MqttSource.Handler

      handler_state = %{
        source_pid: pid,
        subtype: "application/octet-stream",
        broker_url: @broker_url
      }

      # Simulate the reception of mqtt messages by manually invoking the handler
      Handler.handle_message(["mytopic"], "payload", handler_state)
      Handler.handle_message(["another", "topic"], "another payload", handler_state)
      Handler.handle_message(["binary", "stuff"], <<1, 2, 3, 4>>, handler_state)

      messages =
        GenStage.stream([pid])
        |> Enum.take(3)

      assert [
               %Message{
                 key: "mytopic",
                 data: "payload",
                 type: :binary,
                 subtype: "application/octet-stream",
                 metadata: %{
                   "Astarte.Streams.Blocks.MqttSource.broker_url" => @broker_url
                 }
               },
               %Message{
                 key: "another/topic",
                 data: "another payload",
                 type: :binary,
                 subtype: "application/octet-stream",
                 metadata: %{
                   "Astarte.Streams.Blocks.MqttSource.broker_url" => @broker_url
                 }
               },
               %Message{
                 key: "binary/stuff",
                 data: <<1, 2, 3, 4>>,
                 type: :binary,
                 subtype: "application/octet-stream",
                 metadata: %{
                   "Astarte.Streams.Blocks.MqttSource.broker_url" => @broker_url
                 }
               }
             ] = messages
    end
  end
end
