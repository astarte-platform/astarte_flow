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
  @enforce_keys [
    :key,
    :data,
    :type,
    :timestamp
  ]

  defstruct [
    :subtype,
    {:metadata, %{}}
    | @enforce_keys
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
  @type data_type :: %{String.t() => data_type_with_array()} | data_type_with_array()
  @type subtype :: nil | String.t() | %{String.t() => String.t()}
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
          subtype: subtype(),
          timestamp: message_timestamp(),
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

      iex> %Message{
      ...>   data: 42,
      ...>   key: "meaning-of-life",
      ...>   metadata: %{},
      ...>   timestamp: 1551884045074181,
      ...>   type: :integer
      ...> }
      ...> |> Message.to_map()
      %{
        "schema" => "astarte_streams/message/v0.1",
        "data" => 42,
        "key" => "meaning-of-life",
        "metadata" => %{},
        "timestamp" => 1551884045074,
        "timestamp_us" => 181,
        "type" => "integer"
      }

      iex> %Message{
      ...>   data: <<0, 1, 2, 0>>,
      ...>   key: "binaries_stream",
      ...>   metadata: %{},
      ...>   timestamp: 1551884045074181,
      ...>   type: :binary,
      ...>   subtype: "application/octet-stream"
      ...> }
      ...> |> Message.to_map()
      %{
        "schema" => "astarte_streams/message/v0.1",
        "data" => "AAECAA==",
        "key" => "binaries_stream",
        "metadata" => %{},
        "timestamp" => 1551884045074,
        "timestamp_us" => 181,
        "type" => "binary",
        "subtype" => "application/octet-stream"
      }

      iex> %Message{
      ...>   data: %{
      ...>     "a" => -1,
      ...>     "b" => "Ciao\n"
      ...>   },
      ...>   key: "binaries_stream",
      ...>   metadata: %{},
      ...>   timestamp: 1551884045074181,
      ...>   type: %{
      ...>     "a" => :real,
      ...>     "b" => :binary
      ...>   },
      ...>   subtype: %{
      ...>     "b" => "text/plain"
      ...>   }
      ...> }
      ...> |> Message.to_map()
      %{
        "schema" => "astarte_streams/message/v0.1",
        "data" => %{
          "a" => -1,
          "b" => "Q2lhbwo="
        },
        "key" => "binaries_stream",
        "metadata" => %{},
        "timestamp" => 1551884045074,
        "timestamp_us" => 181,
        "type" => %{
          "a" => "real",
          "b" => "binary"
        },
        "subtype" => %{
          "b" => "text/plain"
        }
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
      "type" => serialize_type(type),
      "timestamp" => div(timestamp, 1000),
      "timestamp_us" => rem(timestamp, 1000),
      "data" => wrap_data(data, type)
    }
    |> maybe_put("subtype", subtype)
  end

  defp maybe_put(map, _key, nil) do
    map
  end

  defp maybe_put(map, key, value) do
    Map.put(map, key, value)
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
      ...>   "type" => "integer"
      ...> }
      ...> |> Message.from_map()
      {:ok,
        %Message{
        data: 42,
        key: "meaning-of-life",
        metadata: %{},
        timestamp: 1551884045074181,
        type: :integer
      }}

      iex> %{
      ...>   "schema" => "astarte_streams/message/v0.1",
      ...> }
      ...> |> Message.from_map()
      {:error, :invalid_message}

      iex> Message.from_map(%{})
      {:error, :invalid_message}
  """
  @spec from_map(%{required(String.t()) => term()}) :: Message.t() | {:error, :invalid_message}
  def from_map(%{"schema" => @message_schema_version} = map) do
    with %{
           "key" => key,
           "metadata" => metadata,
           "type" => type_string,
           "timestamp" => millis,
           "timestamp_us" => micros,
           "data" => wrapped_data
         } <- map,
         true <- String.valid?(key),
         true <- valid_metadata?(metadata),
         {:ok, type_atom} <- deserialize_type(type_string),
         subtype <- Map.get(map, "subtype"),
         true <- String.valid?(subtype || ""),
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

  def from_map(_any) do
    {:error, :invalid_message}
  end

  @spec deserialize_type(String.t() | %{String.t() => String.t()}) ::
          {:ok, data_type()} | {:error, :invalid_message_type}
  def deserialize_type(message_type) do
    case message_type do
      type_string_map when is_map(type_string_map) ->
        Enum.reduce_while(type_string_map, {:ok, %{}}, fn {key, type_string}, {:ok, acc} ->
          case deserialize_type_with_array(type_string) do
            {:ok, type} -> {:cont, {:ok, Map.put(acc, key, type)}}
            {:error, :invalid_message_type} -> {:halt, {:error, :invalid_message_type}}
          end
        end)

      maybe_with_array ->
        deserialize_type_with_array(maybe_with_array)
    end
  end

  @spec deserialize_type_with_array(String.t()) ::
          {:ok, data_type_with_array()} | {:error, :invalid_message_type}
  defp deserialize_type_with_array(message_type) do
    case message_type do
      "integer_array" -> {:ok, {:array, :integer}}
      "real_array" -> {:ok, {:array, :real}}
      "boolean_array" -> {:ok, {:array, :boolean}}
      "datetime_array" -> {:ok, {:array, :datetime}}
      "binary_array" -> {:ok, {:array, :binary}}
      "string_array" -> {:ok, {:array, :string}}
      maybe_basic -> deserialize_basic_type(maybe_basic)
    end
  end

  @spec deserialize_basic_type(String.t()) ::
          {:ok, basic_data_type()} | {:error, :invalid_message_type}
  defp deserialize_basic_type(message_type) do
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

  @spec serialize_type(basic_data_type()) :: String.t()
  def serialize_type(data_type) do
    case data_type do
      :integer ->
        "integer"

      :real ->
        "real"

      :boolean ->
        "boolean"

      :datetime ->
        "datetime"

      :binary ->
        "binary"

      :string ->
        "string"

      {:array, :integer} ->
        "integer_array"

      {:array, :real} ->
        "real_array"

      {:array, :boolean} ->
        "boolean_array"

      {:array, :datetime} ->
        "datetime_array"

      {:array, :binary} ->
        "binary_array"

      {:array, :string} ->
        "string_array"

      type_map when is_map(type_map) ->
        Enum.reduce(type_map, %{}, fn {key, type}, acc ->
          Map.put(acc, key, serialize_type(type))
        end)
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

  @spec valid_metadata?(term()) :: boolean()
  defp valid_metadata?(metadata) do
    if is_map(metadata) do
      Enum.all?(metadata, fn {k, v} -> String.valid?(k) and String.valid?(v) end)
    else
      false
    end
  end

  @doc ~S"""
  Converts a value to a "wrapped" value that can be easily serialized.

  ## Examples

      iex> Message.wrap_data(42, :integer)
      42

      iex> Message.wrap_data(0.5, :real)
      0.5

      iex> Message.wrap_data(false, :boolean)
      false

      iex> Message.wrap_data(<<0, 1, 2, 3>>, :binary)
      "AAECAw=="

      iex> Message.wrap_data("Hello World", :string)
      "Hello World"

      iex> Message.wrap_data([0, 1, 2], {:array, :integer})
      [0, 1, 2]

      iex> %{"my_key" => <<0, 1>>}
      ...> |> Message.wrap_data(%{"my_key" => :binary})
      %{"my_key" => "AAE="}
  """
  @spec wrap_data(integer(), :integer) :: integer()
  def wrap_data(data, :integer) when is_integer(data) do
    data
  end

  @spec wrap_data(number(), :real) :: number()
  def wrap_data(data, :real) when is_number(data) do
    data
  end

  @spec wrap_data(boolean(), :boolean) :: boolean()
  def wrap_data(data, :boolean) when is_boolean(data) do
    data
  end

  @spec wrap_data(DateTime.t(), :datetime) :: String.t()
  def wrap_data(%DateTime{} = data, :datetime) do
    DateTime.to_iso8601(data)
  end

  @spec wrap_data(binary(), :binary) :: String.t()
  def wrap_data(data, :binary) when is_binary(data) do
    Base.encode64(data)
  end

  @spec wrap_data(String.t(), :string) :: String.t()
  def wrap_data(data, :string) when is_binary(data) do
    data
  end

  @spec wrap_data([basic_data()], {:array, basic_data_type()}) :: list()
  def wrap_data(data, {:array, array_type}) when is_list(data) do
    for array_value <- data do
      wrap_data(array_value, array_type)
    end
  end

  @spec wrap_data(%{optional(String.t()) => {atom(), String.t(), data_with_array()}}, :map) :: %{
          optional(String.t()) => %{optional(String.t()) => term()}
        }
  def wrap_data(data, types_map) when is_map(data) and is_map(types_map) do
    Enum.reduce(data, %{}, fn {key, value}, acc ->
      value_type = Map.fetch!(types_map, key)
      wrapped_value = wrap_data(value, value_type)
      Map.put(acc, key, wrapped_value)
    end)
  end

  @doc ~S"""
  Converts a "wrapped" value to a value that can be used as a Message data.

  ## Examples

      iex> Message.unwrap_data(42, :integer)
      {:ok, 42}

      iex> Message.unwrap_data(0.5, :real)
      {:ok, 0.5}

      iex> Message.unwrap_data(true, :boolean)
      {:ok, true}

      iex> Message.unwrap_data("dGVzdA==", :binary)
      {:ok, "test"}

      iex> Message.unwrap_data("Hello World", :string)
      {:ok, "Hello World"}

      iex> Message.unwrap_data([1, 2, 3], {:array, :integer})
      {:ok, [1, 2, 3]}

      iex> Message.unwrap_data([1, 2.5, 3], {:array, :integer})
      {:error, :invalid_data}

      iex> %{
      ...>   "key1" => "AAECAQA=",
      ...>   "key2" => [-1, 0, 0.5, 1]
      ...> }
      ...> |> Message.unwrap_data(%{"key1" => :binary, "key2" => {:array, :real}})
      {:ok,
        %{
          "key1" => <<0, 1, 2, 1, 0>>,
          "key2" => [-1, 0, 0.5, 1]
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
  def unwrap_data(wrapped_data, type_map) when is_map(wrapped_data) and is_map(type_map) do
    Enum.reduce_while(wrapped_data, {:ok, %{}}, fn {key, wrapped_value}, {:ok, acc} ->
      with {:ok, type} <- Map.fetch(type_map, key),
           {:ok, value} <- unwrap_data(wrapped_value, type) do
        {:cont, {:ok, Map.put(acc, key, value)}}
      else
        _any -> {:halt, {:error, :invalid_data}}
      end
    end)
  end

  def unwrap_data(_any_value, any_type) when is_atom(any_type) do
    {:error, :invalid_data}
  end
end
