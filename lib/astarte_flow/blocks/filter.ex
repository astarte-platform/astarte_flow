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

defmodule Astarte.Flow.Blocks.Filter do
  use GenStage

  alias Astarte.Flow.Blocks.FilterFunctions
  alias Astarte.Flow.Message

  defmodule Config do
    defstruct [
      :good_func
    ]
  end

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # GenStage callbacks

  @impl true
  def init(opts) do
    filter_config = Keyword.fetch!(opts, :filter_config)

    with {:ok, func} <- FilterFunctions.make_filter(filter_config) do
      config = %Config{good_func: func}
      {:producer_consumer, config, dispatcher: GenStage.BroadcastDispatcher}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_events(events, _from, config) do
    filtered_events = Enum.filter(events, &good?(config, &1))

    {:noreply, filtered_events, config}
  end

  defp good?(%Config{} = config, %Message{} = message) do
    %Config{
      good_func: good_func
    } = config

    good_func.(message)
  end
end
