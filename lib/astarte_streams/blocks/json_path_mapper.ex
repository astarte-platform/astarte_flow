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

defmodule Astarte.Streams.Blocks.JsonPathMapper do
  @moduledoc """
  Transforms the incoming JSON message using the configured JSON template which makes use of
  JSONPath to extract data from the incoming message.
  """

  use GenStage
  alias Astarte.Streams.Blocks.JsonPathMapper.JsonTemplate
  alias Astarte.Streams.Message
  require Logger

  defmodule Config do
    @moduledoc false

    defstruct [
      :compiled_template
    ]

    @type t() :: %__MODULE__{compiled_template: map()}

    @type option() :: {:template, String.t()}

    @doc """
    Initialize config from a keyword list.

    ## Options

      * `:template` - output message template. It must be a valid JSON that makes use of JSONPath.
    """
    @spec from_keyword(list(option())) :: {:ok, t()}
    def from_keyword(kl) do
      with {:ok, template} <- Keyword.fetch(kl, :template),
           {:ok, template_map} <- Jason.decode(template),
           {:ok, compiled_template} <- JsonTemplate.compile_template(template_map) do
        {:ok,
         %Config{
           compiled_template: compiled_template
         }}
      else
        :error ->
          {:error, :missing_template}

        _any ->
          {:error, :invalid_template}
      end
    end
  end

  @doc """
  Starts the `JsonPathMapper`.

  ## Options

    * `:template` - output message template. It must be a valid JSON that makes use of JSONPath.
  """
  @spec start_link(list(Config.option())) :: GenServer.on_start()
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    with {:ok, config} <- Config.from_keyword(opts) do
      {:producer_consumer, config, dispatcher: GenStage.BroadcastDispatcher}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_events(events, _from, %Config{} = config) do
    msgs_list =
      Enum.reduce(events, [], fn msg, acc ->
        case json_path_transform(msg, config) do
          {:ok, msg} ->
            [msg | acc]

          any ->
            _ = Logger.warn("Error while mapping message to json.", message: msg, data: any)
            acc
        end
      end)
      |> Enum.reverse()

    {:noreply, msgs_list, config}
  end

  @doc """
  Transforms the given message according to the configured template.
  """
  @spec json_path_transform(Message.t(), Config.t()) :: {:ok, Message.t()} | {:error, any()}
  def json_path_transform(%Message{} = msg, %Config{compiled_template: template}) do
    with %Message{data: data, type: :binary} <- msg,
         {:ok, decoded_json} <- Jason.decode(data),
         data_map = %{"data" => decoded_json},
         {:ok, rendered_map} <- JsonTemplate.render(template, data_map),
         {:render, %{"data" => data, "type" => serialized_type}} <- {:render, rendered_map},
         {:ok, type} <- Message.deserialize_type(serialized_type),
         {:ok, typed_data} <- cast_data(data, type),
         msg_with_data_and_type = %Message{msg | data: typed_data, type: type, subtype: nil} do
      merge_message(msg_with_data_and_type, rendered_map)
    else
      %Message{} -> {:error, :unsupported_type}
      {:render, _} -> {:error, :invalid_template_render}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cast_data(data, type_map) when is_map(data) and is_map(type_map) do
    Enum.reduce_while(data, {:ok, %{}}, fn {key, item}, {:ok, acc} ->
      item_type = Map.fetch!(type_map, key)

      case cast_data(item, item_type) do
        {:ok, typed_data} -> {:cont, {:ok, Map.put(acc, key, typed_data)}}
        {:error, :cannot_cast_data} -> {:halt, {:error, :cannot_cast_data}}
      end
    end)
  end

  defp cast_data(data, {:array, type}) when is_list(data) and not is_map(type) do
    result =
      Enum.reduce_while(data, {:ok, []}, fn item, {:ok, acc} ->
        case cast_data(item, type) do
          {:ok, typed_data} -> {:cont, {:ok, [typed_data | acc]}}
          {:error, :cannot_cast_data} -> {:halt, {:error, :cannot_cast_data}}
        end
      end)

    case result do
      {:ok, reversed_array} -> {:ok, Enum.reverse(reversed_array)}
      {:error, :cannot_cast_data} -> {:error, :cannot_cast_data}
    end
  end

  defp cast_data(data, {:array, type}) when not is_map(data) and not is_map(type) do
    with {:ok, typed_data} <- cast_data(data, type) do
      {:ok, [typed_data]}
    end
  end

  defp cast_data(data, :integer) when is_number(data) do
    as_integer =
      data
      |> Float.round()
      |> Kernel.trunc()

    {:ok, as_integer}
  end

  defp cast_data(data, :real) when is_number(data) do
    {:ok, data * 1.0}
  end

  defp cast_data(data, :boolean) when is_boolean(data) do
    {:ok, data}
  end

  defp cast_data(data, :datetime) when is_binary(data) do
    case DateTime.from_iso8601(data) do
      {:ok, datetime, 0} ->
        {:ok, datetime}
        {:error, :cannot_cast_data}
    end
  end

  defp cast_data(data, :string) when is_binary(data) do
    if String.valid?(data) do
      {:ok, data}
    else
      {:error, :cannot_cast_data}
    end
  end

  defp cast_data(data, :binary) when is_binary(data) do
    {:ok, data}
  end

  defp cast_data(_data, type) when is_atom(type) do
    {:error, :cannot_cast_data}
  end

  defp merge_message(the_message, map) do
    Enum.reduce_while(map, {:ok, the_message}, fn {key_bin, value}, {:ok, acc} ->
      case key_bin do
        "key" ->
          {:cont, {:ok, %Message{acc | key: value}}}

        "metadata" ->
          {:cont, {:ok, %Message{acc | metadata: Enum.into(value, %{})}}}

        "subtype" ->
          {:cont, {:ok, %Message{acc | subtype: value}}}

        "timestamp" ->
          int_timestamp =
            value
            |> Float.round()
            |> Kernel.trunc()

          {:cont, {:ok, %Message{acc | timestamp: int_timestamp}}}

        "data" ->
          {:cont, {:ok, acc}}

        "type" ->
          {:cont, {:ok, acc}}

        _key ->
          {:halt, {:error, :invalid_template_render}}
      end
    end)
  end
end
