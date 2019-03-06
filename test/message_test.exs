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

alias Astarte.Streams.Message

defmodule Astarte.Streams.MessageTest do
  use ExUnit.Case
  doctest Astarte.Streams.Message

  test "JSON serialization and deserialization" do
    message = %Message{
      data: 340_282_366_920_938_463_463_374_607_431_768_211_456,
      key: "big_integers_stream0",
      metadata: %{"base" => "2", "exponent" => "128"},
      timestamp: :erlang.system_time(:microsecond),
      type: :integer
    }

    assert Jason.encode!(message, pretty: true) |> Jason.decode!() |> Message.from_map() ==
             {:ok, message}
  end
end
