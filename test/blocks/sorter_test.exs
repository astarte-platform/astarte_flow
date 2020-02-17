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

defmodule Astarte.Flow.Blocks.SorterTest do
  use ExUnit.Case
  alias Astarte.Flow.Blocks.Sorter
  alias Astarte.Flow.Blocks.Sorter.Config
  alias Astarte.Flow.Blocks.Sorter.State
  alias Astarte.Flow.Message

  test "reorder messages" do
    msg1 = %Message{
      data: 1,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_955_684_855_188,
      type: :integer
    }

    msg2 = %Message{
      data: 2,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_955_685_406_741,
      type: :integer
    }

    msg3 = %Message{
      data: 3,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_955_678_100_980,
      type: :integer
    }

    in_messages = [msg1, msg2, msg3]
    expected_messages = [msg3, msg1, msg2]

    {:ok, config} = Config.from_keyword([])

    state =
      Enum.reduce(in_messages, %State{}, fn message, state ->
        Sorter.process_message(message, config, state)
      end)

    {out_messages, {config, state}} = Sorter.take_ready(0, {config, state})

    assert out_messages == []

    {out_messages, {config, state}} = Sorter.take_ready(1_579_955_792_927_853, {config, state})

    assert out_messages == expected_messages

    {out_messages, {_config, _state}} = Sorter.take_ready(1_579_955_892_927_853, {config, state})

    assert out_messages == []
  end

  test "deduplicate messages" do
    msg1 = %Message{
      data: 1,
      key: "key",
      metadata: %{"test" => "a"},
      timestamp: 1_579_955_678_100_980,
      type: :integer
    }

    msg2 = %Message{
      data: 2,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_955_685_406_741,
      type: :integer
    }

    msg3 = %Message{
      data: 1,
      key: "key",
      metadata: %{"test" => "b"},
      timestamp: 1_579_955_678_100_980,
      type: :integer
    }

    in_messages = [msg1, msg2, msg3]
    expected_messages = [msg3, msg2]

    {:ok, config} = Config.from_keyword(deduplicate: true)

    state =
      Enum.reduce(in_messages, %State{}, fn message, state ->
        Sorter.process_message(message, config, state)
      end)

    {out_messages, {config, state}} = Sorter.take_ready(0, {config, state})

    assert out_messages == []

    {out_messages, {config, state}} = Sorter.take_ready(1_579_955_792_927_853, {config, state})

    assert erase_metadata(out_messages) == erase_metadata(expected_messages)

    {out_messages, {_config, _state}} = Sorter.take_ready(1_579_955_892_927_853, {config, state})

    assert out_messages == []
  end

  defp erase_metadata(messages) do
    Enum.map(messages, fn msg ->
      %Message{msg | metadata: %{}}
    end)
  end

  test "deduplicate is not default behavior" do
    msg1 = %Message{
      data: 1,
      key: "key",
      metadata: %{"test" => "a"},
      timestamp: 1_579_955_678_100_980,
      type: :integer
    }

    msg2 = %Message{
      data: 2,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_955_685_406_741,
      type: :integer
    }

    msg3 = %Message{
      data: 1,
      key: "key",
      metadata: %{"test" => "b"},
      timestamp: 1_579_955_678_100_980,
      type: :integer
    }

    in_messages = [msg1, msg2, msg3]
    expected_messages = [msg3, msg3, msg2]

    {:ok, config} = Config.from_keyword([])

    state =
      Enum.reduce(in_messages, %State{}, fn message, state ->
        Sorter.process_message(message, config, state)
      end)

    {out_messages, {config, state}} = Sorter.take_ready(0, {config, state})

    assert out_messages == []

    {out_messages, {config, state}} = Sorter.take_ready(1_579_955_792_927_853, {config, state})

    assert extract_timestamp(out_messages) == extract_timestamp(expected_messages)

    {out_messages, {_config, _state}} = Sorter.take_ready(1_579_955_892_927_853, {config, state})

    assert out_messages == []
  end

  defp extract_timestamp(messages) do
    Enum.map(messages, fn msg ->
      msg.timestamp
    end)
  end

  test "output only ready messages" do
    msg1 = %Message{
      data: 1,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_955_684_855_188,
      type: :integer
    }

    msg2 = %Message{
      data: 2,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_955_685_406_741,
      type: :integer
    }

    msg3 = %Message{
      data: 4,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_960_457_151_353,
      type: :integer
    }

    msg4 = %Message{
      data: 3,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_579_955_678_100_980,
      type: :integer
    }

    in_messages = [msg1, msg2, msg3, msg4]
    expected_messages = [msg4, msg1, msg2]

    {:ok, config} = Config.from_keyword(deduplicate: true)

    state =
      Enum.reduce(in_messages, %State{}, fn message, state ->
        Sorter.process_message(message, config, state)
      end)

    {out_messages, {config, state}} = Sorter.take_ready(0, {config, state})

    assert out_messages == []

    {out_messages, {config, state}} = Sorter.take_ready(1_579_955_792_927_853, {config, state})

    assert out_messages == expected_messages

    {out_messages, {_config, _state}} = Sorter.take_ready(1_579_955_892_927_853, {config, state})

    assert out_messages == []
  end

  test "too old messages are not accepted" do
    msg1 = %Message{
      data: 1,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 10001,
      type: :integer
    }

    msg2 = %Message{
      data: 2,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 10100,
      type: :integer
    }

    msg3 = %Message{
      data: 3,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 10101,
      type: :integer
    }

    msg4 = %Message{
      data: 4,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 9999,
      type: :integer
    }

    in_messages = [msg1, msg2, msg3, msg4]

    {:ok, config} = Config.from_keyword(deduplicate: false, delay_ms: 10)

    initial_state = %State{
      last_timestamp: 20000
    }

    state =
      Enum.reduce(in_messages, initial_state, fn message, state ->
        Sorter.process_message(message, config, state)
      end)

    {out_messages, {config, state}} = Sorter.take_ready(20002, {config, state})

    assert out_messages == [msg1]

    {out_messages, {config, state}} = Sorter.take_ready(20102, {config, state})

    assert out_messages == [msg2, msg3]

    {out_messages, {_config, _state}} = Sorter.take_ready(30000, {config, state})

    assert out_messages == []
  end
end
