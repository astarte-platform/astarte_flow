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

defmodule Astarte.Flow.Blocks.LuaMapper do
  @moduledoc """
  This is a map block that takes an incoming `Message` and it transforms it using given Lua script.
  This block supports Lua 5.3 scripts. The incoming message will be provided to the script as
  `message`
  """

  use GenStage
  alias Astarte.Flow.Message
  require Logger

  defmodule Config do
    @moduledoc false

    defstruct [
      :luerl_chunk,
      :luerl_state
    ]

    @type t() :: %__MODULE__{}

    @type option() :: {:script, String.t()}

    @doc """
    Initialize config from a keyword list.

    ## Options

      * `:script` - a Lua 5.3 script. Defaults to `"return message;"`.
    """
    @spec from_keyword(list(option())) :: {:ok, t()}
    def from_keyword(kl) do
      lua_script = Keyword.get(kl, :script, "return message;")

      luerl_state =
        :luerl.init()
        |> intialize_lua_tables()

      with {:ok, chunk, state} <- :luerl.load(lua_script, luerl_state) do
        {:ok,
         %Config{
           luerl_chunk: chunk,
           luerl_state: state
         }}
      else
        any ->
          _ = Logger.warn("Error while loading Lua script: #{inspect(any)}")
          {:error, :invalid_lua_script}
      end
    end

    defp intialize_lua_tables(luerl_state) do
      uuid_table = [
        {:get_v5_base64,
         fn [namespace, string], state ->
           base64enc =
             UUID.uuid5(namespace, string)
             |> UUID.string_to_binary!()
             |> Base.url_encode64(padding: false)

           {[base64enc], state}
         end}
      ]

      :luerl.set_table([:uuid], uuid_table, luerl_state)
    end
  end

  @doc """
  Starts the `LuaMapper`.

  ## Options

    * `:script` - a Lua 5.3 script. Defaults to `"return message;"`.
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
        case lua_map(msg, config) do
          {:ok, msg} ->
            [msg | acc]

          any ->
            _ = Logger.warn("Error while running lua_map script.", message: msg, data: any)
            acc
        end
      end)
      |> Enum.reverse()

    {:noreply, msgs_list, config}
  end

  @doc """
  Executes the Lua script and returns the new message created using the script.
  """
  @spec lua_map(Message.t(), Config.t()) :: {:ok, Message.t()} | {:error, reason :: term()}
  def lua_map(%Message{} = msg, %Config{luerl_chunk: chunk, luerl_state: state}) do
    lua_message = message_to_lua(msg)

    state = :luerl.set_table([:message], lua_message, state)

    with {:ok, [eval_result]} <- :luerl.eval(chunk, state) do
      {:ok, message_from_lua(eval_result, msg)}
    end
  end

  defp message_to_lua(msg) do
    %Message{
      key: key,
      metadata: metadata,
      type: type,
      subtype: subtype,
      timestamp: timestamp,
      data: data
    } = msg

    [
      {"key", key},
      {"metadata", metadata},
      {"type", Message.serialize_type(type)},
      {"subtype", subtype},
      {"timestamp", timestamp},
      {"data", data}
    ]
  end

  defp message_from_lua(lua_msg, default_message) do
    Enum.reduce(lua_msg, default_message, fn {key_bin, value}, acc ->
      case key_bin do
        "key" ->
          %Message{acc | key: value}

        "metadata" ->
          %Message{acc | metadata: Enum.into(value, %{})}

        "type" ->
          %Message{acc | type: cast_type(value)}

        "subtype" ->
          %Message{acc | subtype: value}

        "timestamp" ->
          int_timestamp =
            value
            |> Float.round()
            |> Kernel.trunc()

          %Message{acc | timestamp: int_timestamp}

        "data" ->
          %Message{acc | data: value}

        key ->
          _ = Logger.warn("Unexpected key in lua message: #{key}.")
          acc
      end
    end)
    |> cast_data()
  end

  defp cast_type(map_type) when is_list(map_type) do
    {:ok, type} =
      Enum.into(map_type, %{})
      |> Message.deserialize_type()

    type
  end

  defp cast_type(type_string) when is_binary(type_string) do
    {:ok, type} = Message.deserialize_type(type_string)
    type
  end

  defp cast_data(%Message{data: data, type: type} = msg) do
    %Message{msg | data: cast_data(data, type)}
  end

  defp cast_data(data, :integer) do
    data
    |> Float.round()
    |> Kernel.trunc()
  end

  defp cast_data(data, {:array, type}) do
    Enum.map(data, fn {_index, item_value} ->
      cast_data(item_value, type)
    end)
  end

  defp cast_data(data, type_map) when is_list(data) and is_map(type_map) do
    Enum.reduce(data, %{}, fn {key, item}, acc ->
      item_type = Map.fetch!(type_map, key)
      Map.put(acc, key, cast_data(item, item_type))
    end)
  end

  defp cast_data(data, _type) do
    data
  end
end
