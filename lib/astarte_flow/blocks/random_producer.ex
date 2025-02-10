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

defmodule Astarte.Flow.Blocks.RandomProducer do
  @moduledoc """
  Producer module that generates random messages of a specific type with a fixed key. The supported types are `:integer`, `:real` and `:boolean`.

  The data generated for each type is the following:

    * `:integer` generates a random integer between `:min` and `:max` (defaults to `min = 0` and `max = 100`).
    * `:real` generates a random float between `:min` and `:max` (defaults to `min = 0` and `max = 1`).
    * `:boolean` generates `true` with probability `:p` (defaults to `p = 0.5`), otherwise `false`.

  The message timestamp will be generated with DateTime.utc_now().
  """

  use GenStage

  alias Astarte.Flow.Message

  @type options() :: [option]

  @type option() ::
          {:key, String.t()}
          | {:type, supported_types()}
          | {:delay_ms, integer()}
          | integer_option()
          | real_option()
          | boolean_option()

  @type integer_option() ::
          {:min, integer()}
          | {:max, integer()}

  @type real_option() ::
          {:min, float()}
          | {:max, float()}

  @type boolean_option() ::
          {:p, float()}

  @type supported_types() :: :integer | :real | :boolean

  defmodule Config do
    @moduledoc false

    defstruct [
      :key,
      :type,
      :min,
      :max,
      :p,
      :delay_ms,
      :pending_demand,
      :queue
    ]
  end

  @doc """
  Starts the `RandomProducer`.

  ## Options

    * `:key` (required) - A unicode string that will be used as key in the generated messages
    * `:type` (required) - The type of data that will be generated. Supported types are `:integer`, `:real` and `:boolean`
    * `:min` - Used with `:integer` and `:real` types to define a min value.
    * `:max` - Used with `:integer` and `:real` types to define a max value.
    * `:p` - Used with `:boolean` type to define the probability of the generator returning `true`. The value must be `>= 0` and `<= 1`.
    * `:delay_ms` - If not `nil`, the block will wait `delay_ms` before emitting a new sample
  """
  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # GenStage callbacks

  @impl true
  def init(opts) do
    key = Keyword.fetch!(opts, :key)
    type = Keyword.get(opts, :type, "real") |> String.to_existing_atom()

    with {:ok, type} <- validate_type(type),
         {:ok, state} <- init_state(key, type, opts) do
      delay_ms = Keyword.get(opts, :delay_ms) || 0
      send(self(), :poll)

      {:producer, %Config{state | delay_ms: delay_ms, pending_demand: 0, queue: :queue.new()},
       dispatcher: GenStage.BroadcastDispatcher}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_demand(incoming_demand, %Config{pending_demand: demand} = config) do
    dispatch_messages(%{config | pending_demand: demand + incoming_demand}, [
      generate_message(config)
    ])
  end

  @impl true
  def handle_info(:poll, config) do
    %Config{
      delay_ms: delay_ms,
      queue: queue
    } = config

    # Schedule next polling
    _ = Process.send_after(self(), :poll, delay_ms)

    new_queue =
      generate_message(config)
      |> :queue.in(queue)

    new_state = %{config | queue: new_queue}
    dispatch_messages(new_state, [])
  end

  defp dispatch_messages(%Config{pending_demand: 0} = state, messages) do
    {:noreply, Enum.reverse(messages), state}
  end

  defp dispatch_messages(%Config{pending_demand: demand, queue: queue} = state, messages) do
    case :queue.out(queue) do
      {{:value, message}, updated_queue} ->
        updated_state = %{state | pending_demand: demand - 1, queue: updated_queue}
        updated_messages = [message | messages]

        dispatch_messages(updated_state, updated_messages)

      {:empty, _queue} ->
        {:noreply, Enum.reverse(messages), state}
    end
  end

  defp validate_type(type) when type in [:integer, :real, :boolean] do
    {:ok, type}
  end

  defp validate_type(_) do
    {:error, :unsupported_type}
  end

  defp init_state(key, :integer, opts) do
    with {:min, min} when is_integer(min) <- {:min, Keyword.get(opts, :min, 0)},
         {:max, max} when is_integer(max) <- {:max, Keyword.get(opts, :max, 100)} do
      {:ok, %Config{key: key, type: :integer, min: min, max: max}}
    else
      {:min, _} ->
        {:error, :invalid_min}

      {:max, _} ->
        {:error, :invalid_max}
    end
  end

  defp init_state(key, :real, opts) do
    with {:min, min} when is_number(min) <- {:min, Keyword.get(opts, :min, 0)},
         {:max, max} when is_number(max) <- {:max, Keyword.get(opts, :max, 1)} do
      {:ok, %Config{key: key, type: :real, min: min, max: max}}
    else
      {:min, _} ->
        {:error, :invalid_min}

      {:max, _} ->
        {:error, :invalid_max}
    end
  end

  defp init_state(key, :boolean, opts) do
    case Keyword.get(opts, :p, 0.5) do
      p when is_number(p) and p >= 0 and 0 <= 1 ->
        {:ok, %Config{key: key, type: :real, p: p}}

      _ ->
        {:error, :invalid_p}
    end
  end

  defp generate_message(%Config{key: key, type: type, delay_ms: delay_ms} = state) do
    data = generate_data(state)

    %Message{
      key: key,
      type: type,
      data: data,
      timestamp: DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    }
  end

  defp generate_data(%Config{type: :integer, min: min, max: max}) do
    Enum.random(min..max)
  end

  defp generate_data(%Config{type: :real, min: min, max: max}) do
    :rand.uniform() * (max - min) + min
  end

  defp generate_data(%Config{type: :boolean, p: p}) do
    :rand.uniform() < p
  end
end
