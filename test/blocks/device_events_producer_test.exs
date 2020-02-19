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

defmodule Astarte.Flow.Blocks.DeviceEventsProducerTest do
  use ExUnit.Case

  alias Astarte.Flow.Blocks.DeviceEventsProducer
  alias Astarte.Flow.Blocks.DeviceEventsProducer.EventsDecoder
  alias Astarte.Flow.Message

  alias Astarte.Core.Triggers.SimpleEvents.{
    DeviceConnectedEvent,
    IncomingDataEvent,
    SimpleEvent,
    ValueChangeEvent
  }

  defmodule FakeAMQPClient do
    @behaviour Astarte.Flow.Blocks.DeviceEventsProducer.AMQPClient

    def generate_config(_opts) do
      {:ok, %{}}
    end

    def setup_channel(_config) do
      conn_pid = spawn(fn -> :timer.sleep(:infinity) end)
      chan_pid = spawn(fn -> :timer.sleep(:infinity) end)

      {:ok, %{pid: chan_pid, conn: %{pid: conn_pid}}}
    end

    def consume(_chan, _config) do
      nil
    end

    def ack(_chan, _delivery_tag) do
      :ok
    end

    def reject(_chan, _delivery_tag, _opts \\ []) do
      :ok
    end

    def push_event(pid, %SimpleEvent{} = event) do
      payload = SimpleEvent.encode(event)

      headers = [
        {"x_astarte_realm", :longstr, event.realm},
        {"x_astarte_device_id", :longstr, event.device_id}
      ]

      meta = %{delivery_tag: "fake", headers: headers}

      send(pid, {:basic_deliver, payload, meta})
    end

    def push_payload(pid, payload) do
      meta = %{delivery_tag: "fake"}

      send(pid, {:basic_deliver, payload, meta})
    end

    def close_connection(_) do
      :ok
    end
  end

  describe "DeviceEventsProducer" do
    setup [:start_producer]

    test "converts an IncomingData SimpleEvent to a Message", %{producer: pid} do
      interface = "com.astarte-platform.genericsensors.Values"
      path = "/test/value"
      value = 42.3
      bson_value = %{"v" => value} |> Cyanide.encode!()
      realm = "test"
      device_id = "kRIHRTCWSeCZOC9DhCBIcg"
      timestamp_ms = 1_580_031_400_664
      timestamp_us = timestamp_ms * 1000

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      simple_event = %SimpleEvent{
        realm: realm,
        device_id: device_id,
        timestamp: timestamp_ms,
        event: {:incoming_data_event, event}
      }

      FakeAMQPClient.push_event(pid, simple_event)

      [message] = GenStage.stream([pid]) |> Enum.take(1)

      assert %Message{
               key: "#{realm}/#{device_id}/#{interface}#{path}",
               type: :real,
               data: value,
               timestamp: timestamp_us
             } == message
    end

    test "ignores a DeviceConnected SimpleEvent", %{producer: pid} do
      realm = "test"
      device_id = "kRIHRTCWSeCZOC9DhCBIcg"
      timestamp_ms = 1_580_031_400_664

      event = %DeviceConnectedEvent{
        device_ip_address: "1.2.3.4"
      }

      device_connected_event = %SimpleEvent{
        realm: realm,
        device_id: device_id,
        timestamp: timestamp_ms,
        event: {:device_connected_event, event}
      }

      FakeAMQPClient.push_event(pid, device_connected_event)
      FakeAMQPClient.push_event(pid, event_fixture())

      assert GenStage.stream([pid]) |> Enum.take(1) == [message_fixture()]
    end

    test "ignores a ValueChangeEvent SimpleEvent", %{producer: pid} do
      interface = "com.astarte-platform.genericsensors.Values"
      path = "/test/value"
      old_value = 42.3
      old_bson_value = %{"v" => old_value} |> Cyanide.encode!()
      new_value = 22.1
      new_bson_value = %{"v" => new_value} |> Cyanide.encode!()
      realm = "test"
      device_id = "kRIHRTCWSeCZOC9DhCBIcg"
      timestamp_ms = 1_580_031_400_664

      event = %ValueChangeEvent{
        interface: interface,
        path: path,
        old_bson_value: old_bson_value,
        new_bson_value: new_bson_value
      }

      value_change_event = %SimpleEvent{
        realm: realm,
        device_id: device_id,
        timestamp: timestamp_ms,
        event: {:device_connected_event, event}
      }

      FakeAMQPClient.push_event(pid, value_change_event)
      FakeAMQPClient.push_event(pid, event_fixture())

      assert GenStage.stream([pid]) |> Enum.take(1) == [message_fixture()]
    end

    test "ignores random payloads", %{producer: pid} do
      FakeAMQPClient.push_payload(pid, "someotherstuff")
      FakeAMQPClient.push_event(pid, event_fixture())

      assert GenStage.stream([pid]) |> Enum.take(1) == [message_fixture()]
    end
  end

  describe "DeviceEventsProducer filter" do
    test "ignores Events for other device ids" do
      device_id = "kRIHRTCWSeCZOC9DhCBIcg"
      other_device_id = "aqaF_EfBSUubaexIkm9XVA"

      {:ok, pid} =
        DeviceEventsProducer.start_link(
          routing_key: "test",
          realm: "test",
          target_devices: [device_id],
          client: FakeAMQPClient
        )

      interface = "com.astarte-platform.genericsensors.Values"
      path = "/test/value"
      value = 42.3
      bson_value = %{"v" => value} |> Cyanide.encode!()
      realm = "test"
      timestamp_ms = 1_580_031_400_664
      timestamp_us = timestamp_ms * 1000

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      other_simple_event = %SimpleEvent{
        realm: realm,
        device_id: other_device_id,
        timestamp: timestamp_ms,
        event: {:incoming_data_event, event}
      }

      ok_simple_event = %SimpleEvent{
        realm: realm,
        device_id: device_id,
        timestamp: timestamp_ms,
        event: {:incoming_data_event, event}
      }

      FakeAMQPClient.push_event(pid, other_simple_event)
      FakeAMQPClient.push_event(pid, ok_simple_event)

      [message] = GenStage.stream([pid]) |> Enum.take(1)

      assert %Message{
               key: "#{realm}/#{device_id}/#{interface}#{path}",
               type: :real,
               data: value,
               timestamp: timestamp_us
             } == message
    end

    test "ignores Events for other realm" do
      realm = "test"
      other_realm = "other"

      {:ok, pid} =
        DeviceEventsProducer.start_link(
          routing_key: "test",
          realm: realm,
          client: FakeAMQPClient
        )

      interface = "com.astarte-platform.genericsensors.Values"
      path = "/test/value"
      value = 42.3
      bson_value = %{"v" => value} |> Cyanide.encode!()
      device_id = "kRIHRTCWSeCZOC9DhCBIcg"
      timestamp_ms = 1_580_031_400_664
      timestamp_us = timestamp_ms * 1000

      event = %IncomingDataEvent{
        interface: interface,
        path: path,
        bson_value: bson_value
      }

      other_simple_event = %SimpleEvent{
        realm: other_realm,
        device_id: device_id,
        timestamp: timestamp_ms,
        event: {:incoming_data_event, event}
      }

      ok_simple_event = %SimpleEvent{
        realm: realm,
        device_id: device_id,
        timestamp: timestamp_ms,
        event: {:incoming_data_event, event}
      }

      FakeAMQPClient.push_event(pid, other_simple_event)
      FakeAMQPClient.push_event(pid, ok_simple_event)

      [message] = GenStage.stream([pid]) |> Enum.take(1)

      assert %Message{
               key: "#{realm}/#{device_id}/#{interface}#{path}",
               type: :real,
               data: value,
               timestamp: timestamp_us
             } == message
    end
  end

  describe "EventsDecoder.decode_simple_event" do
    test "returns error when decoding random binary" do
      assert {:error, :decode_failed} = EventsDecoder.decode_simple_event(<<1, 2, 3>>)
    end

    test "correctly decodes a SimpleEvent" do
      event_binary = event_fixture() |> SimpleEvent.encode()
      assert {:ok, %SimpleEvent{} = event} = EventsDecoder.decode_simple_event(event_binary)
      assert event == event_fixture()
    end
  end

  describe "EventsDecoder.simple_event_to_message" do
    test "correctly infers types" do
      assert {:ok, %Message{type: :real, data: 21.3}} =
               event_fixture(value: 21.3) |> EventsDecoder.simple_event_to_message()

      assert {:ok, %Message{type: :integer, data: 3}} =
               event_fixture(value: 3) |> EventsDecoder.simple_event_to_message()

      assert {:ok, %Message{type: :string, data: "hello"}} =
               event_fixture(value: "hello") |> EventsDecoder.simple_event_to_message()

      assert {:ok, %Message{type: :datetime, data: %DateTime{}}} =
               event_fixture(value: DateTime.utc_now()) |> EventsDecoder.simple_event_to_message()

      # This is how Cyanide represents BSON binaries
      assert {:ok, %Message{type: :binary, data: <<1, 2, 3, 4>>}} =
               event_fixture(value: {0, <<1, 2, 3, 4>>})
               |> EventsDecoder.simple_event_to_message()
    end

    test "temporarily fails with aggregation object" do
      assert {:error, :object_aggregation_not_yet_supported} =
               event_fixture(value: %{an: "object", other: "value"})
               |> EventsDecoder.simple_event_to_message()
    end

    test "populates the timestamp if it's nil" do
      assert {:ok, %Message{timestamp: timestamp}} =
               event_fixture(value: "hello", timestamp: nil)
               |> EventsDecoder.simple_event_to_message()

      assert is_number(timestamp)
    end
  end

  defp event_fixture(opts \\ []) do
    interface = Keyword.get(opts, :interface, "com.astarte-platform.genericsensors.Values")
    path = Keyword.get(opts, :path, "/test/value")
    value = Keyword.get(opts, :value, 42.3)
    bson_value = %{"v" => value} |> Cyanide.encode!()
    realm = Keyword.get(opts, :realm, "test")
    device_id = Keyword.get(opts, :device_id, "kRIHRTCWSeCZOC9DhCBIcg")
    timestamp_ms = Keyword.get(opts, :timestamp_ms, 1_580_031_400_664)

    event = %IncomingDataEvent{
      interface: interface,
      path: path,
      bson_value: bson_value
    }

    %SimpleEvent{
      realm: realm,
      device_id: device_id,
      timestamp: timestamp_ms,
      event: {:incoming_data_event, event}
    }
  end

  defp message_fixture(opts \\ []) do
    interface = Keyword.get(opts, :interface, "com.astarte-platform.genericsensors.Values")
    path = Keyword.get(opts, :path, "/test/value")
    value = Keyword.get(opts, :value, 42.3)
    realm = Keyword.get(opts, :realm, "test")
    device_id = Keyword.get(opts, :device_id, "kRIHRTCWSeCZOC9DhCBIcg")
    timestamp_ms = Keyword.get(opts, :timestamp_ms, 1_580_031_400_664)

    timestamp_us =
      if timestamp_ms do
        timestamp_ms * 1000
      else
        nil
      end

    %Message{
      key: "#{realm}/#{device_id}/#{interface}#{path}",
      type: :real,
      data: value,
      timestamp: timestamp_us
    }
  end

  defp start_producer(_context) do
    {:ok, pid} =
      DeviceEventsProducer.start_link(routing_key: "test", realm: "test", client: FakeAMQPClient)

    {:ok, producer: pid}
  end
end
