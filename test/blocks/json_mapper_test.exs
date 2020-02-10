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

defmodule Astarte.Flow.Blocks.JsonMapperTest do
  use ExUnit.Case
  alias Astarte.Flow.Blocks.JsonMapper
  alias Astarte.Flow.Blocks.JsonMapper.Config
  alias Astarte.Flow.Message

  test "real valued message to JSON" do
    real_value_message = %Message{
      data: 42.1,
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: :real
    }

    real_json_message = %Message{
      data: "42.1",
      key: "test",
      subtype: "application/json",
      timestamp: 1_560_955_493_916_854,
      type: :binary
    }

    {:ok, config} = Config.from_keyword(pretty: false)

    assert JsonMapper.to_json(real_value_message, config) == {:ok, real_json_message}
  end

  test "string valued message to JSON" do
    string_value_message = %Message{
      data: "test string",
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_560_955_493_916_854,
      type: :string
    }

    string_json_message = %Message{
      data: ~s("test string"),
      key: "key",
      metadata: %{"test" => "metadata"},
      subtype: "application/json",
      timestamp: 1_560_955_493_916_854,
      type: :binary
    }

    {:ok, config} = Config.from_keyword(pretty: false)

    assert JsonMapper.to_json(string_value_message, config) == {:ok, string_json_message}
  end

  test "int array valued message to JSON" do
    int_arr_value_message = %Message{
      data: [1, 0, 3, -1, 5],
      key: "key",
      metadata: %{"test" => "metadata"},
      timestamp: 1_560_955_493_916_854,
      type: {:array, :integer}
    }

    int_arr_json_message = %Message{
      data: "[1,0,3,-1,5]",
      key: "key",
      metadata: %{"test" => "metadata"},
      subtype: "application/json",
      timestamp: 1_560_955_493_916_854,
      type: :binary
    }

    {:ok, config} = Config.from_keyword(pretty: false)

    assert JsonMapper.to_json(int_arr_value_message, config) == {:ok, int_arr_json_message}
  end

  test "map valued message to JSON" do
    int_arr_value_message = %Message{
      data: %{"x" => {:integer, "", -50}, "y" => {:integer, "", 0}},
      key: "key",
      timestamp: 1_560_955_493_916_854,
      type: :map
    }

    int_arr_json_message = %Message{
      data: ~s({"x":-50,"y":0}),
      key: "key",
      subtype: "application/json",
      timestamp: 1_560_955_493_916_854,
      type: :binary
    }

    {:ok, config} = Config.from_keyword([])

    assert JsonMapper.to_json(int_arr_value_message, config) == {:ok, int_arr_json_message}
  end
end
