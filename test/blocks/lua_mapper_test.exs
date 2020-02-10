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

defmodule Astarte.Flow.Blocks.LuaMapperTest do
  use ExUnit.Case
  alias Astarte.Flow.Blocks.LuaMapper
  alias Astarte.Flow.Blocks.LuaMapper.Config
  alias Astarte.Flow.Message

  test "identity lua mapping" do
    message = %Message{
      data: <<0, 1, 2, 3, 0>>,
      key: "test key",
      metadata: %{"test0" => "metadata0", "test1" => "metadata1"},
      timestamp: 1_560_955_493_916_860,
      type: :binary,
      subtype: "application/octet-stream"
    }

    lua_script = """
      return message;
    """

    {:ok, config} = Config.from_keyword(script: lua_script)

    assert LuaMapper.lua_map(message, config) == {:ok, message}
  end

  test "lua map an integer message to a map message" do
    int_value_message = %Message{
      data: 5,
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_560_955_493_916_854,
      type: :integer
    }

    expected_message = %Message{
      data: %{"x" => -50, "y" => 0},
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_560_955_493_916_854,
      type: %{"x" => :integer, "y" => :integer}
    }

    lua_script = """
      new_message = {};
      new_message.data = {x = message.data * -10, y = 0};
      new_message.type = {x = "integer", y = "integer"};
      new_message.metadata = message.metadata;
      return new_message;
    """

    {:ok, config} = Config.from_keyword(script: lua_script)

    assert LuaMapper.lua_map(int_value_message, config) == {:ok, expected_message}
  end

  test "lua map an array message to an array message" do
    int_array_message = %Message{
      data: [0, 0, 1, -1, 2, -2],
      key: "key",
      timestamp: 1_560_955_493_916_854,
      type: {:array, :integer}
    }

    expected_message = %Message{
      data: [0, 0, -1, 1, -2, 2],
      key: "key",
      timestamp: 1_560_955_493_916_854,
      type: {:array, :integer}
    }

    lua_script = """
      new_message = {};
      new_message.data = {};
      for i=1,6 do
        new_message.data[i] = message.data[i] * -1;
      end
      return new_message;
    """

    {:ok, config} = Config.from_keyword(script: lua_script)

    assert LuaMapper.lua_map(int_array_message, config) == {:ok, expected_message}
  end
end
