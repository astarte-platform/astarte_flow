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

defmodule Astarte.Flow.Blocks.JsonMapper do
  @moduledoc """
  This is a map block that takes `data` from incoming `Message` and makes a Message having a JSON
  serialized payload. The `subtype` of the message  is set to "application/json" and the `type` is
  `:binary`.
  """

  use GenStage
  alias Astarte.Flow.Message
  require Logger

  defmodule Config do
    @moduledoc false

    defstruct [
      :pretty,
      :template
    ]

    @type t() :: %__MODULE__{pretty: boolean(), template: any()}

    @type option() :: {:pretty, boolean()} | {:template, any()}

    @doc """
    Initialize config from a keyword list.

    ## Options

      * `:pretty` - serialize the output to pretty format that is easier to read for humans.
      * `:template` - a JSONTemplate applied right before serialization.
    """
    @spec from_keyword(list(option())) :: {:ok, t()}
    def from_keyword(kl) do
      pretty = Keyword.get(kl, :pretty, false)

      case Keyword.fetch(kl, :template) do
        {:ok, template} ->
          with {:ok, compiled_template} <- ExJSONTemplate.compile_template(template) do
            {:ok,
             %Config{
               pretty: pretty,
               template: compiled_template
             }}
          end

        :error ->
          {:ok,
           %Config{
             pretty: pretty
           }}
      end
    end
  end

  @doc """
  Starts the `JsonMapper`.

  ## Options

    * `:pretty` - serialize the output to pretty format that is easier to read for humans.
    * `:template` - a JSONTemplate applied right before serialization.
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
        case to_json(msg, config) do
          {:ok, msg} ->
            [msg | acc]

          any ->
            _ = Logger.warning("Error while mapping message to json.", message: msg, data: any)
            acc
        end
      end)
      |> Enum.reverse()

    {:noreply, msgs_list, config}
  end

  @doc """
  Makes a new Message with JSON serialzed data, `:binary` type and "application/json" subtype.
  """
  @spec to_json(Message.t(), Config.t()) :: {:ok, Message.t()} | {:error, any()}
  def to_json(%Message{} = msg, %Config{pretty: pretty, template: compiled_template}) do
    with {:ok, data} <- maybe_apply_template(msg, compiled_template),
         {:ok, encoded} <- Jason.encode(data, pretty: pretty) do
      {:ok, %Message{msg | type: :binary, subtype: "application/json", data: encoded}}
    end
  end

  defp maybe_apply_template(%Message{data: data, type: type} = _msg, _no_template = nil) do
    {:ok, Message.wrap_data(data, type)}
  end

  defp maybe_apply_template(msg, compiled_template) do
    input = %{"message" => Message.to_map(msg)}
    ExJSONTemplate.render(compiled_template, input)
  end
end
