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

alias Astarte.Streams.Message

defmodule Astarte.Streams.Message do
  defstruct [
    :key,
    :metadata,
    :type,
    :subtype,
    :timestamp,
    :data
  ]

  @message_schema_version "astarte_streams/message/v0.1"

  @type basic_data ::
          integer()
          | float()
          | boolean()
          | DateTime.t()
          | binary()
          | String.t()
  @type data_with_array :: basic_data() | [basic_data()]
  @type data :: data_with_array() | %{optional(String.t()) => data_with_array()}

  @type message_metadata :: %{optional(String.t()) => String.t()}

  @type basic_data_type :: :integer | :real | :boolean | :datetime | :binary | :string
  @type data_type_with_array :: basic_data_type() | {:array, basic_data_type()}
  @type data_type :: :map | data_type_with_array()
  @type message_timestamp :: integer()

  @typedoc """
  An Astarte Streams message.

  * `:key`: a unicode string that identifies the stream the message belongs to.
  * `:metadata`: additional message metadata.
  * `:type': message data type (e.g. integer, real, boolean, etc...).
  * `:subtype`: a string that represents the subtype, that is a mimetype for binaries.
  * `:timestamp`: timestamp in microseconds.
  * `:data`: the message payload.
  """
  @type t :: %Message{
          key: String.t(),
          metadata: message_metadata(),
          type: data_type(),
          subtype: String.t(),
          timestamp: non_neg_integer(),
          data: data()
        }

  defimpl Jason.Encoder, for: Message do
    def encode(message, opts) do
      Message.to_map(message)
      |> Jason.Encode.map(opts)
    end
  end

  @doc ~S"""
  Converts a Message struct to a serialization friendly map, so it can be used with a JSON serializer.

  ## Examples

      iex> %Astarte.Streams.Message{
      ...>   data: 42,
      ...>   key: "meaning-of-life",
      ...>   metadata: %{},
      ...>   timestamp: 1551884045074181,
      ...>   type: :integer
      ...> }
      ...> |> Astarte.Streams.Message.to_map()
      %{
        "schema" => "astarte_streams/message/v0.1",
        "data" => 42,
        "key" => "meaning-of-life",
        "metadata" => %{},
        "timestamp" => 1551884045074,
        "timestamp_us" => 181,
        "type" => :integer,
        "subtype" => nil
      }
  """
  @spec to_map(Message.t()) :: %{required(String.t()) => term()}
  def to_map(%Message{} = message) do
    %Message{
      key: key,
      metadata: metadata,
      type: type,
      subtype: subtype,
      timestamp: timestamp,
      data: data
    } = message

    %{
      "schema" => @message_schema_version,
      "key" => key,
      "metadata" => metadata,
      "type" => type,
      "subtype" => subtype,
      "timestamp" => div(timestamp, 1000),
      "timestamp_us" => rem(timestamp, 1000),
      "data" => data
    }
  end

  @doc ~S"""
  Converts a message map to a Message struct, this function is useful for handling JSON decoded messages.

  ## Examples

      iex> %{
      ...>   "schema" => "astarte_streams/message/v0.1",
      ...>   "data" => 42,
      ...>   "key" => "meaning-of-life",
      ...>   "metadata" => %{},
      ...>   "timestamp" => 1551884045074,
      ...>   "timestamp_us" => 181,
      ...>   "type" => "integer",
      ...>   "subtype" => nil
      ...> }
      ...> |> Astarte.Streams.Message.from_map()
      {:ok,
        %Astarte.Streams.Message{
        data: 42,
        key: "meaning-of-life",
        metadata: %{},
        timestamp: 1551884045074181,
        type: :integer
      }}
  """
  @spec from_map(%{required(String.t()) => term()}) :: Message.t() | {:error, :invalid_message}
  def from_map(%{"schema" => @message_schema_version} = map) do
    with %{
           "key" => key,
           "metadata" => metadata,
           "type" => type_string,
           "subtype" => subtype,
           "timestamp" => millis,
           "timestamp_us" => micros,
           "data" => data
         } <- map,
         {:ok, type_atom} <- type_from_string(type_string),
         {:ok, timestamp} <- ms_us_to_timestamp(millis, micros) do
      message = %Message{
        key: key,
        metadata: metadata,
        type: type_atom,
        subtype: subtype,
        timestamp: timestamp,
        data: data
      }

      {:ok, message}
    else
      _ ->
        {:error, :invalid_message}
    end
  end

  @spec type_from_string(String.t()) :: {:ok, data_type()} | {:error, :invalid_message_type}
  defp type_from_string(message_type) do
    case message_type do
      "map" -> {:ok, :map}
      maybe_with_array -> type_with_array_from_string(maybe_with_array)
    end
  end

  @spec type_with_array_from_string(String.t()) ::
          {:ok, data_type_with_array()} | {:error, :invalid_message_type}
  defp type_with_array_from_string(message_type) do
    case message_type do
      "integer_array" -> {:ok, {:array, :integer}}
      "real_array" -> {:ok, {:array, :real}}
      "boolean_array" -> {:ok, {:array, :boolean}}
      "datetime_array" -> {:ok, {:array, :datetime}}
      "binary_array" -> {:ok, {:array, :binary}}
      "string_array" -> {:ok, {:array, :string}}
      maybe_basic -> basic_type_from_string(maybe_basic)
    end
  end

  @spec basic_type_from_string(String.t()) ::
          {:ok, basic_data_type()} | {:error, :invalid_message_type}
  defp basic_type_from_string(message_type) do
    case message_type do
      "integer" -> {:ok, :integer}
      "real" -> {:ok, :real}
      "boolean" -> {:ok, :boolean}
      "datetime" -> {:ok, :datetime}
      "binary" -> {:ok, :binary}
      "string" -> {:ok, :string}
      _ -> {:error, :invalid_message_type}
    end
  end

  @spec ms_us_to_timestamp(integer(), integer()) ::
          {:ok, integer()} | {:error, :invalid_timestamp}
  defp ms_us_to_timestamp(millis, micros) do
    if is_integer(millis) and is_integer(micros) and micros >= 0 and micros < 1000 do
      {:ok, millis * 1000 + micros}
    else
      {:error, :invalid_timestamp}
    end
  end
end
