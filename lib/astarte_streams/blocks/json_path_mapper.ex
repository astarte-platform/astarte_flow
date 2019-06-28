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
           compiled_template = compile_template(template_map) do
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

    defp compile_template(template_array) when is_list(template_array) do
      Enum.map(template_array, fn
        value when is_map(value) ->
          compile_template(value)

        value when is_list(value) ->
          compile_template(value)

        value ->
          wrap_item(value)
      end)
    end

    defp compile_template(template_map) when is_map(template_map) do
      Enum.map(template_map, fn
        {key, value} when is_map(value) ->
          {wrap_item(key), compile_template(value)}

        {key, value} when is_list(value) ->
          {wrap_item(key), compile_template(value)}

        {key, value} ->
          {wrap_item(key), wrap_item(value)}
      end)
      |> Enum.into(%{})
    end

    defp wrap_item(item) when is_binary(item) do
      case String.trim(item) do
        "{{" <> rest ->
          if String.slice(rest, -2, 2) == "}}" do
            path_string = String.slice(rest, 0..-3)
            {:ok, json_path} = ExJsonPath.compile(path_string)
            {:json_path, json_path}
          else
            item
          end

        any ->
          any
      end
    end

    defp wrap_item(item) do
      item
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
         transformed_map = replace(template, data_map),
         %{"data" => data, "type" => serialized_type} <- transformed_map,
         {:ok, type} <- Message.deserialize_type(serialized_type),
         {:ok, typed_data} <- cast_data(data, type) do
      {:ok, %Message{msg | data: typed_data, type: type}}
    else
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

  defp replace(template, input) when is_map(template) do
    Enum.reduce(template, %{}, fn {key, value}, acc ->
      Map.put(acc, replace(key, input), replace(value, input))
    end)
  end

  defp replace({:json_path, path}, input) do
    case ExJsonPath.eval(input, path) do
      [result] -> result
      result -> result
    end
  end

  defp replace(value, _input) do
    value
  end
end
