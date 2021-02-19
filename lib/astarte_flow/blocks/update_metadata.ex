#
# This file is part of Astarte.
#
# Copyright 2021 Ispirata Srl
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

defmodule Astarte.Flow.Blocks.UpdateMetadata do
  @moduledoc """
  This is a producer-consumer block that modifies the `metadata` field of
  incoming `Message`s by inserting, updating or removing keys using a static
  configuration.
  """

  use GenStage
  require Logger

  defmodule Config do
    @moduledoc false

    defstruct [
      :keys_to_drop,
      :metadata_merge_map
    ]

    @type t() :: %__MODULE__{keys_to_drop: list(String.t()), metadata_merge_map: map()}

    @type option() :: {:metadata, map()}

    @doc """
    Initialize config from a keyword list.

    ## Options

    * `:metadata` - The metadata map. All keys present in the object are either
    inserted or updated in the `Message` metadata, with the only exception
    that if a key has a value of null, it will be removed from metadata
    (required, object with string keys and string or null values)
    """
    @spec from_keyword(list(option())) :: {:ok, t()} | {:error, reason :: term()}
    def from_keyword(opts) do
      with {:ok, metadata} <- Keyword.fetch(opts, :metadata),
           :ok <- check_metadata(metadata) do
        {to_be_dropped, upserts} = Enum.split_with(metadata, fn {_k, v} -> v == nil end)

        merge_map = Enum.into(upserts, %{})
        keys_to_drop = Enum.map(to_be_dropped, fn {k, _v} -> k end)

        config = %Config{
          metadata_merge_map: merge_map,
          keys_to_drop: keys_to_drop
        }

        {:ok, config}
      else
        :error ->
          {:error, :missing_metadata}

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp check_metadata(metadata) do
      Enum.reduce_while(metadata, :ok, fn {k, v}, _acc ->
        cond do
          not String.valid?(k) ->
            {:halt, {:error, :invalid_metadata_key}}

          not String.valid?(v) and v != nil ->
            {:halt, {:error, :invalid_metadata_value}}

          true ->
            {:cont, :ok}
        end
      end)
    end
  end

  @doc """
  Starts the `UpdateMetadata` block.

  ## Options

    * `:metadata` - The metadata map. All keys present in the object are either
      inserted or updated in the `Message` metadata, with the only exception
      that if a key has a value of null, it will be removed from metadata
      (required, object with string keys and string or null values)
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
  def handle_events(events, _from, config) do
    %Config{
      keys_to_drop: keys_to_drop,
      metadata_merge_map: metadata_merge_map
    } = config

    updated_msgs =
      Enum.map(events, fn message ->
        metadata = message.metadata || %{}

        updated_metadata =
          Map.drop(metadata, keys_to_drop)
          |> Map.merge(metadata_merge_map)

        %{message | metadata: updated_metadata}
      end)

    {:noreply, updated_msgs, config}
  end
end
