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

defmodule Astarte.Flow.Blocks.MapSplitterTest do
  use ExUnit.Case
  alias Astarte.Flow.Blocks.MapSplitter
  alias Astarte.Flow.Blocks.MapSplitter.Config
  alias Astarte.Flow.Message

  test "split a map typed message into different messages" do
    in_message = %Message{
      data: %{
        "a" => 1,
        "b" => 2.2,
        "c" => 3
      },
      key: "test_key",
      metadata: %{"test0" => "metadata0", "test1" => "metadata1"},
      timestamp: 1_560_955_493_916_860,
      type: %{
        "a" => :integer,
        "b" => :real,
        "c" => :integer
      }
    }

    out_messages =
      [
        %Message{
          data: 1,
          key: "test_key/a",
          metadata: %{"test0" => "metadata0", "test1" => "metadata1"},
          timestamp: 1_560_955_493_916_860,
          type: :integer
        },
        %Message{
          data: 2.2,
          key: "test_key/b",
          metadata: %{"test0" => "metadata0", "test1" => "metadata1"},
          timestamp: 1_560_955_493_916_860,
          type: :real
        },
        %Message{
          data: 3,
          key: "test_key/c",
          metadata: %{"test0" => "metadata0", "test1" => "metadata1"},
          timestamp: 1_560_955_493_916_860,
          type: :integer
        }
      ]
      |> MapSet.new()

    {:ok, config} = Config.from_keyword(key_action: {:append, "/"})

    assert extract(MapSplitter.split_map(in_message, config)) == {:ok, out_messages}
  end

  test "pass through any other message type" do
    in_message = %Message{
      data: <<1, 2, 3, 4>>,
      key: "test_key",
      metadata: %{"test0" => "metadata0", "test1" => "metadata1"},
      timestamp: 1_560_955_493_916_860,
      type: :binary
    }

    out_messages = [in_message]

    {:ok, config} = Config.from_keyword(fallback_action: :pass_through)

    assert MapSplitter.split_map(in_message, config) == {:ok, out_messages}
  end

  defp extract({:ok, out}) when is_list(out) do
    {:ok, MapSet.new(out)}
  end

  defp extract(any) do
    any
  end
end
