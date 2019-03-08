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
           "data" => wrapped_data
         } <- map,
         {:ok, type_atom} <- type_from_string(type_string),
         {:ok, data} <- unwrap_data(wrapped_data, type_atom),
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

  @doc ~S"""
  Converts a "wrapped" value to a value that can be used as a Message data.

  ## Examples

      iex> Astarte.Streams.Message.unwrap_data(42, :integer)
      {:ok, 42}

      iex> Astarte.Streams.Message.unwrap_data(0.5, :real)
      {:ok, 0.5}

      iex> Astarte.Streams.Message.unwrap_data(true, :boolean)
      {:ok, true}

      iex> Astarte.Streams.Message.unwrap_data("dGVzdA==", :binary)
      {:ok, "test"}

      iex> Astarte.Streams.Message.unwrap_data("Hello World", :string)
      {:ok, "Hello World"}

      iex> Astarte.Streams.Message.unwrap_data([1, 2, 3], {:array, :integer})
      {:ok, [1, 2, 3]}

      iex> Astarte.Streams.Message.unwrap_data([1, 2.5, 3], {:array, :integer})
      {:error, :invalid_data}

      iex> %{
      ...>   "key1" => %{
      ...>     "type" => "binary",
      ...>     "subtype" => "application/octet-stream",
      ...>     "data" => "AAECAQA="
      ...>   }
      ...> }
      ...> |> Astarte.Streams.Message.unwrap_data(:map)
      {:ok,
        %{
          "key1" => {:binary, "application/octet-stream", <<0, 1, 2, 1, 0>>}
        }
      }
  """
  @spec unwrap_data(integer(), :integer) :: {:ok, integer()} | {:error, :invalid_data}
  def unwrap_data(wrapped_data, :integer) when is_integer(wrapped_data) do
    {:ok, wrapped_data}
  end

  @spec unwrap_data(float(), :real) :: {:ok, float()} | {:error, :invalid_data}
  def unwrap_data(wrapped_data, :real) when is_number(wrapped_data) do
    {:ok, wrapped_data}
  end

  @spec unwrap_data(boolean(), :boolean) :: {:ok, boolean()} | {:error, :invalid_data}
  def unwrap_data(wrapped_data, :boolean) when is_boolean(wrapped_data) do
    {:ok, wrapped_data}
  end

  @spec unwrap_data(String.t(), :datetime) :: {:ok, DateTime.t()} | {:error, :invalid_data}
  def unwrap_data(wrapped_data, :datetime) when is_binary(wrapped_data) do
    with {:ok, dt, _} <- DateTime.from_iso8601(wrapped_data) do
      {:ok, dt}
    else
      _any ->
        {:error, :invalid_data}
    end
  end

  @spec unwrap_data(binary(), :binary) :: {:ok, binary()} | {:error, :invalid_data}
  def unwrap_data(wrapped_data, :binary) when is_binary(wrapped_data) do
    case Base.decode64(wrapped_data) do
      :error ->
        {:error, :invalid_data}

      result ->
        result
    end
  end

  @spec unwrap_data(String.t(), :string) :: {:ok, String.t()} | {:error, :invalid_data}
  def unwrap_data(wrapped_data, :string) when is_binary(wrapped_data) do
    if String.valid?(wrapped_data) do
      {:ok, wrapped_data}
    else
      {:error, :invalid_data}
    end
  end

  @spec unwrap_data(list(), {:array, basic_data_type()}) ::
          {:ok, [basic_data_type()]} | {:error, :invalid_data}
  def unwrap_data(wrapped_data, {:array, array_type})
      when is_list(wrapped_data) and is_atom(array_type) do
    with {:ok, reversed_list} <-
           Enum.reduce_while(wrapped_data, {:ok, []}, fn list_item, {:ok, acc} ->
             case unwrap_data(list_item, array_type) do
               {:ok, unwrapped_item} ->
                 acc_list = [unwrapped_item | acc]
                 {:cont, {:ok, acc_list}}

               _invalid ->
                 {:halt, {:error, :invalid_data}}
             end
           end) do
      {:ok, Enum.reverse(reversed_list)}
    end
  end

  @spec unwrap_data(%{optional(String.t()) => term()}, :map) ::
          {:ok, data()} | {:error, :invalid_data}
  def unwrap_data(wrapped_data, :map) when is_map(wrapped_data) do
    Enum.reduce_while(wrapped_data, {:ok, %{}}, &unwrap_map_item/2)
  end

  def unwrap_data(_any_value, any_type) when is_atom(any_type) do
    {:error, :invalid_data}
  end

  defp unwrap_map_item({key, value}, {:ok, acc}) do
    with %{"data" => wrapped_item, "type" => type_string, "subtype" => subtype} <- value,
         {:ok, data_type} <- basic_type_from_string(type_string),
         {:ok, data} <- unwrap_data(wrapped_item, data_type) do
      updated_map = Map.put(acc, key, {data_type, subtype, data})

      {:cont, {:ok, updated_map}}
    else
      _any ->
        {:halt, {:error, :invalid_data}}
    end
  end
end
