#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule Astarte.Streams.Blocks.Sorter do
  @moduledoc """
  This block is a stateful realtime block, which reorders an out of order sequence of messages,
  and optionally removes any duplicate message.
  """
  use GenStage

  alias Astarte.Streams.Message

  defmodule Config do
    defstruct policy: :duplicates,
              delay_us: 1_000_000

    @type t() :: %__MODULE__{}

    @type option() :: {:deduplicate, boolean()} | {:delay_ms, pos_integer()}

    @doc """
    Initialize config from a keyword list.

    ## Options

      * `:deduplicate` - true when messages deduplication is enabled, otherwise false.
        Two messages are duplicate when they have same timestamp and value (any other field is ignored).
      * `:delay_ms` - the amount of time the message is kept for reorder and deduplicate operations.
    """
    @spec from_keyword(list(option())) :: {:ok, t()}

    def from_keyword(kl) do
      deduplicate = Keyword.get(kl, :deduplicate, false)
      delay_ms = Keyword.get(kl, :delay_ms, 1000)

      policy =
        if deduplicate do
          :unique
        else
          :duplicates
        end

      {:ok,
       %Config{
         policy: policy,
         delay_us: delay_ms * 1000
       }}
    end
  end

  defmodule State do
    defstruct last_timestamp: 0,
              queues: %{}

    @type t() :: %__MODULE__{}
  end

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # GenStage callbacks

  @impl true
  def init(opts) do
    with {:ok, config} <- Config.from_keyword(opts) do
      {:ok, _tref} = :timer.send_interval(1, :timer_timeout)

      {:producer_consumer, {config, %State{}}, dispatcher: GenStage.BroadcastDispatcher}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:timer_timeout, state) do
    ts =
      DateTime.utc_now()
      |> DateTime.to_unix(:microsecond)

    {messages, state} = take_ready(ts, state)

    {:noreply, messages, state}
  end

  @doc """
  Take any ready message.
  """
  @spec take_ready(pos_integer(), {Config.t(), State.t()}) ::
          {list(Message.t()), {Config.t(), State.t()}}
  def take_ready(ts, {config, %{queues: queues} = _state}) do
    %Config{
      policy: policy,
      delay_us: delay
    } = config

    {queues, messages} =
      Enum.reduce(queues, {queues, []}, fn {key, queue}, {queues_acc, msg_acc} ->
        {queue, backwards_msg_acc} = dequeue_all_ready(policy, queue, ts + delay, msg_acc)
        msg_acc = Enum.reverse(backwards_msg_acc)

        queues_acc =
          if Prioqueue.empty?(queue) do
            Map.delete(queues_acc, key)
          else
            Map.put(queues_acc, key, queue)
          end

        {queues_acc, msg_acc}
      end)

    new_state = %State{last_timestamp: ts, queues: queues}

    {messages, {config, new_state}}
  end

  defp dequeue_all_ready(:duplicates, queue, ts, msg_acc) do
    case Prioqueue.peek_min(queue) do
      {:ok, %Message{timestamp: peek_ts} = _peek_msg} when peek_ts <= ts ->
        {:ok, {peek, queue}} = Prioqueue.extract_min(queue)
        dequeue_all_ready(:duplicates, queue, ts, [peek | msg_acc])

      {:ok, %Message{timestamp: peek_ts} = _peek_msg} when peek_ts > ts ->
        {queue, msg_acc}

      {:error, :empty} ->
        {queue, msg_acc}
    end
  end

  defp dequeue_all_ready(:unique, queue, ts, msg_acc) do
    {last_ts, last_data} =
      case msg_acc do
        [] -> {nil, nil}
        [%Message{timestamp: last_ts, data: last_data} | _tail] -> {last_ts, last_data}
      end

    case Prioqueue.peek_min(queue) do
      {:ok, %Message{timestamp: ^last_ts, data: ^last_data}} ->
        {:ok, {_peek, queue}} = Prioqueue.extract_min(queue)
        dequeue_all_ready(:unique, queue, ts, msg_acc)

      {:ok, %Message{timestamp: peek_ts} = _peek_msg} when peek_ts <= ts ->
        {:ok, {peek, queue}} = Prioqueue.extract_min(queue)
        dequeue_all_ready(:unique, queue, ts, [peek | msg_acc])

      {:ok, %Message{timestamp: peek_ts} = _peek_msg} when peek_ts > ts ->
        {queue, msg_acc}

      {:error, :empty} ->
        {queue, msg_acc}
    end
  end

  @impl true
  def handle_events(events, _from, {config, state}) do
    new_state =
      Enum.reduce(events, state, fn message, acc ->
        process_message(message, acc)
      end)

    {:noreply, [], {config, new_state}}
  end

  @doc """
  Process a message and stores it into the block state.
  """
  @spec process_message(Message.t(), State.t()) :: State.t()
  def process_message(%Message{} = msg, %{last_timestamp: last_ts, queues: queues} = state) do
    queues = maybe_insert(queues, msg, last_ts)

    %State{state | queues: queues}
  end

  defp maybe_insert(queues, %Message{} = msg, min_ts) do
    if msg.timestamp > min_ts do
      store(queues, msg)
    else
      queues
    end
  end

  defp store(queues, %Message{key: key} = msg) do
    stream_pq =
      with {:ok, pq} <- Map.fetch(queues, key) do
        pq
      else
        :error -> Prioqueue.new([], cmp_fun: &cmp_fun/2)
      end

    stream_pq = Prioqueue.insert(stream_pq, msg)

    Map.put(queues, key, stream_pq)
  end

  defp cmp_fun(%Message{timestamp: ts1}, %Message{timestamp: ts2}) do
    cond do
      ts1 < ts2 -> :lt
      ts1 > ts2 -> :gt
      true -> :eq
    end
  end
end
