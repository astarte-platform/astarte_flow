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

defmodule Astarte.Flow.Blocks.MapSplitter do
  @moduledoc """
  Breaks a map message into several messages, one for each map item.
  """

  use GenStage
  alias Astarte.Flow.Message
  require Logger

  defmodule Config do
    @moduledoc false

    defstruct [
      :key_action,
      :fallback_action
    ]

    @type key_action() ::
            :none | {:replace, String.t()} | {:append, String.t()} | {:prepend, String.t()}
    @type fallback_action() :: :discard | {:replace_key, String.t()} | :pass_through

    @type t() :: %__MODULE__{
            key_action: key_action(),
            fallback_action: fallback_action()
          }

    @type option() :: {:key_action, key_action()} | {:fallback_action, fallback_action()}

    @doc """
    Initialize config from a keyword list.

    ## Options

      * `:key_action` - the action to apply to the message key, such as `:none`,
        `{:replace, delimiter}`, `{:append, delimiter}` and `{:prepend, delimiter}`.
      * `:fallback_action` - fallback action that is performed when a message does not have map
         type, such as `:discard`, `{:replace_key, new_key}` and `:pass_through`.
    """
    @spec from_keyword(list(option())) :: {:ok, t()}
    def from_keyword(kl) do
      key_action = Keyword.get(kl, :key_action, {:replace, ""})
      fallback_action = Keyword.get(kl, :fallback_action, :pass_through)

      {:ok,
       %Config{
         key_action: key_action,
         fallback_action: fallback_action
       }}
    end
  end

  @doc """
  Starts the `MapSplitter`.

  ## Options

    * `:key_action` - the action to apply to the message key, such as `:none`,
      `{:replace, delimiter}`, `{:append, delimiter}` and `{:prepend, delimiter}`.
    * `:fallback_action` - fallback action that is performed when a message does not have map
      type, such as `:discard`, `{:replace_key, new_key}` and `:pass_through`.
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
      Enum.flat_map(events, fn msg ->
        case split_map(msg, config) do
          {:ok, messages} ->
            messages

          any ->
            _ = Logger.warning("Error while running split_map.", message: msg, data: any)
            []
        end
      end)

    {:noreply, msgs_list, config}
  end

  @doc """
  Split a map message into a different message for each key.
  """
  @spec split_map(Message.t(), Config.t()) :: {:ok, [Message.t()]} | {:error, reason :: term()}
  def split_map(message, config)

  def split_map(%Message{type: %{}} = message, %Config{key_action: key_action}) do
    %Message{
      key: message_key,
      data: data_map,
      type: type_map,
      subtype: subtype_map
    } = message

    subtype_map = subtype_map || %{}

    Enum.reduce_while(data_map, {:ok, []}, fn {key, data}, {:ok, acc} ->
      with {:ok, type} <- Map.fetch(type_map, key) do
        subtype = Map.get(subtype_map, key)

        new_key =
          case key_action do
            :none -> message_key
            :replace -> key
            {:append, delimiter} -> "#{message_key}#{delimiter}#{key}"
            {:prepend, delimiter} -> "#{key}#{delimiter}#{message_key}"
          end

        new_msg = %Message{message | key: new_key, type: type, subtype: subtype, data: data}

        {:cont, {:ok, [new_msg | acc]}}
      else
        :error ->
          {:halt, {:error, :malformed_message}}
      end
    end)
  end

  def split_map(%Message{} = message, %Config{fallback_action: action}) do
    case action do
      :discard -> {:ok, []}
      {:replace_key, key} -> {:ok, [%Message{message | key: key}]}
      :pass_through -> {:ok, [message]}
    end
  end
end
