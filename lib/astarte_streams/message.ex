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

  @type message_basic_data ::
          number()
          | boolean()
          | DateTime.t()
          | binary()
          | String.t()
  @type message_data ::
          message_basic_data()
          | %{optional(String.t()) => message_basic_data()}
          | [message_basic_data()]

  @type message_metadata :: %{optional(String.t()) => String.t()}

  @type message_basic_type_atom :: :integer | :real | :boolean | :datetime | :binary | :string
  @type message_type_atom :: :map | {:array, message_basic_type_atom()}

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
  @type t :: %Astarte.Streams.Message{
          key: String.t(),
          metadata: message_metadata(),
          type: message_type_atom(),
          subtype: String.t(),
          timestamp: non_neg_integer(),
          data: message_data()
        }

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
  @spec to_map(Astarte.Streams.Message.t()) :: %{required(String.t()) => term()}
  def to_map(%Astarte.Streams.Message{} = message) do
    %Astarte.Streams.Message{
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
      ...>   "type" => :integer,
      ...>   "subtype" => nil
      ...> }
      ...> |> Astarte.Streams.Message.from_map()
      %Astarte.Streams.Message{
        data: 42,
        key: "meaning-of-life",
        metadata: %{},
        timestamp: 1551884045074181,
        type: :integer
      }
  """
  @spec from_map(%{required(String.t()) => term()}) :: Astarte.Streams.Message.t()
  def from_map(%{"schema" => @message_schema_version} = map) do
    %{
      "key" => key,
      "metadata" => metadata,
      "type" => type,
      "subtype" => subtype,
      "timestamp" => timestamp,
      "timestamp_us" => timestamp_us,
      "data" => data
    } = map

    %Astarte.Streams.Message{
      key: key,
      metadata: metadata,
      type: type,
      subtype: subtype,
      timestamp: timestamp * 1000 + timestamp_us,
      data: data
    }
  end
end
