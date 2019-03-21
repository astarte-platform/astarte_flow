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

defmodule Astarte.Streams.Blocks.FilterFunctionsTest do
  use ExUnit.Case
  doctest Astarte.Streams.Blocks.FilterFunctions
  import ExUnit.CaptureLog
  alias Astarte.Streams.Blocks.FilterFunctions
  alias Astarte.Streams.Message

  test "any other type of value == filter" do
    {:ok, fun} =
      FilterFunctions.make_filter(%{
        operator: :==,
        value: 42,
        value_type: :integer
      })

    assert is_function(fun) == true

    good_message = %Message{
      data: 42,
      type: :integer
    }

    not_good_message = %Message{
      data: -1,
      type: :integer
    }

    not_good_type = %Message{
      data: "42",
      type: :string
    }

    assert fun.(good_message) == true
    assert fun.(not_good_message) == false
    assert fun.(not_good_type) == false
    assert fun.(%Message{}) == false
  end

  test "any other type of value != filter" do
    {:ok, fun} =
      FilterFunctions.make_filter(%{
        operator: :!=,
        value: 42,
        value_type: :integer
      })

    assert is_function(fun) == true

    good_message = %Message{
      data: 0,
      type: :integer
    }

    good_different_type = %Message{
      data: "0",
      type: :string
    }

    not_good_message = %Message{
      data: 42,
      type: :integer
    }

    assert fun.(good_message) == true
    assert fun.(good_different_type) == true
    assert fun.(not_good_message) == false
    assert fun.(%Message{}) == true
  end

  test "invalid data when using == filter on any type of message" do
    {:ok, fun} =
      FilterFunctions.make_filter(%{
        operator: :==,
        value: "test",
        value_type: :integer
      })

    assert is_function(fun) == true

    invalid_data_fun = fn ->
      assert fun.(:invalid_data) == false
    end

    assert capture_log(invalid_data_fun) =~ "FilterFunctions: invalid data:"
  end

  test "invalid data when using != filter on any type of message" do
    {:ok, fun} =
      FilterFunctions.make_filter(%{
        operator: :!=,
        value: 4.2,
        value_type: :real
      })

    assert is_function(fun) == true

    invalid_data_fun = fn ->
      assert fun.(:invalid_data) == false
    end

    assert capture_log(invalid_data_fun) =~ "FilterFunctions: invalid data:"
  end

  test "luerl script based filter" do
    {:ok, fun} =
      FilterFunctions.make_filter(%{operator: :luerl_script, script: "return message.data > 20;"})

    assert is_function(fun) == true

    good_message = %Message{
      data: 21,
      type: :integer
    }

    not_good_message = %Message{
      data: 20,
      type: :integer
    }

    assert fun.(good_message) == true
    assert fun.(not_good_message) == false
  end

  test "luerl script failure handling" do
    {:ok, fun} =
      FilterFunctions.make_filter(%{operator: :luerl_script, script: "return message.data > 20;"})

    assert is_function(fun) == true

    not_good_type = %Message{
      data: "21",
      type: :string
    }

    not_good_type_fun = fn ->
      assert fun.(not_good_type) == false
    end

    assert capture_log(not_good_type_fun) =~ "FilterFunctions: luerl unexpected:"
  end

  test "invalid data when using luerl script filter" do
    {:ok, fun} =
      FilterFunctions.make_filter(%{operator: :luerl_script, script: "return message.data > 20;"})

    assert is_function(fun) == true

    invalid_data_fun = fn ->
      assert fun.(:invalid_data) == false
    end

    assert capture_log(invalid_data_fun) =~ "FilterFunctions: invalid data:"
  end

  test "failure on invalid luerl script" do
    invalid_filter_fun = fn ->
      assert FilterFunctions.make_filter(%{operator: :luerl_script, script: "some garbage here!"}) ==
               {:error, :invalid_filter}
    end

    assert capture_log(invalid_filter_fun) =~ "FilterFunctions: luerl error"
  end
end
