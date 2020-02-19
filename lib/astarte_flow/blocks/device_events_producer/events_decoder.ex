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

defmodule Astarte.Flow.Blocks.DeviceEventsProducer.EventsDecoder do
  @moduledoc """
  This module handles the decoding of Astarte Events and their transformation
  to Astarte Flow Messages
  """

  alias Astarte.Core.Triggers.SimpleEvents.{
    IncomingDataEvent,
    SimpleEvent
  }

  alias Astarte.Flow.Message

  @spec decode_simple_event(payload :: binary()) ::
          {:ok, decode_event :: Astarte.Core.Triggers.SimpleEvents.t()}
          | {:error, reason :: term()}
  def decode_simple_event(payload) when is_binary(payload) do
    try do
      decoded = SimpleEvent.decode(payload)
      {:ok, decoded}
    rescue
      _error ->
        {:error, :decode_failed}
    end
  end

  @spec simple_event_to_message(Astarte.Core.Triggers.SimpleEvents.t()) ::
          {:ok, Astarte.Flow.Message.t()} | {:error, reason :: term()}
  def simple_event_to_message(%SimpleEvent{} = simple_event) do
    %SimpleEvent{
      realm: realm,
      device_id: device_id,
      timestamp: timestamp_ms,
      event: {_event_type, event}
    } = simple_event

    timestamp_us =
      if timestamp_ms do
        timestamp_ms * 1000
      else
        DateTime.utc_now()
        |> DateTime.from_unix(:microsecond)
      end

    event_to_message(realm, device_id, event, timestamp_us)
  end

  defp event_to_message(realm, device_id, %IncomingDataEvent{} = event, timestamp) do
    %IncomingDataEvent{
      interface: interface,
      path: path,
      bson_value: bson_value
    } = event

    with {:ok, value} <- extract_bson_value(bson_value),
         {:ok, type} <- value_to_type(value),
         normalized_value = normalize_value(value, type) do
      key = "#{realm}/#{device_id}/#{interface}#{path}"

      message = %Message{
        key: key,
        data: normalized_value,
        type: type,
        timestamp: timestamp
      }

      {:ok, message}
    end
  end

  defp event_to_message(_realm, _device_id, _event, _timestamp) do
    # TODO: support all other event types
    {:error, :unsupported_event}
  end

  defp extract_bson_value(bson_value) do
    case Cyanide.decode(bson_value) do
      # Handle structs (e.g. DateTime) explicitly otherwise they fall in the maps branch
      {:ok, %{"v" => %_{} = value}} ->
        {:ok, value}

      {:ok, %{"v" => value}} ->
        {:ok, value}

      _ ->
        {:error, :invalid_bson_value}
    end
  end

  # TODO: arrays are still missing
  defp value_to_type(value) do
    case value do
      v when is_boolean(v) ->
        {:ok, :boolean}

      v when is_float(v) ->
        {:ok, :real}

      v when is_integer(v) ->
        {:ok, :integer}

      %DateTime{} = _v ->
        {:ok, :datetime}

      v when is_binary(v) ->
        {:ok, :string}

      {subtype, bin} when is_integer(subtype) and is_binary(bin) ->
        {:ok, :binary}

      v when is_map(v) ->
        Enum.reduce_while(v, {:ok, %{}}, fn {item_key, item_value}, {:ok, acc} ->
          case value_to_type(item_value) do
            {:ok, type} -> {:cont, {:ok, Map.put(acc, item_key, type)}}
            error -> {:halt, error}
          end
        end)

      _ ->
        {:error, :unsupported_type}
    end
  end

  # This is just needed to extract Cyanide binaries from the tuple for now
  defp normalize_value({_subtype, binary}, :binary) do
    binary
  end

  defp normalize_value(value, _type) do
    value
  end
end
