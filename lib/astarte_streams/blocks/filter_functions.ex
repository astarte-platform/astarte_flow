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

defmodule Astarte.Streams.Blocks.FilterFunctions do
  alias Astarte.Streams.Message
  require Logger

  def make_filter(%{operator: :==, value: fvalue}) do
    fun = fn
      %Message{data: data} ->
        data == fvalue

      any_invalid ->
        Logger.warn("FilterFunctions: invalid data: #{inspect(any_invalid)}")
        false
    end

    {:ok, fun}
  end

  def make_filter(%{operator: :!=, value: fvalue}) do
    fun = fn
      %Message{data: data} ->
        data != fvalue

      any_invalid ->
        Logger.warn("FilterFunctions: invalid data: #{inspect(any_invalid)}")
        false
    end

    {:ok, fun}
  end

  def make_filter(%{operator: :luerl_script, script: lua_script}) do
    luerl_state = :luerl.init()

    case :luerl.load(lua_script, luerl_state) do
      {:ok, chunk, state} ->
        fun = fn
          %Message{} = msg ->
            state = :luerl.set_table([:message], msg, state)

            case :luerl.eval(chunk, state) do
              {:ok, [result]} ->
                result

              any_unexpected ->
                Logger.warn("FilterFunctions: luerl unexpected: #{inspect(any_unexpected)}")
                false
            end

          any_invalid ->
            Logger.warn("FilterFunctions: invalid data: #{inspect(any_invalid)}")
            false
        end

        {:ok, fun}

      {:error, reason, _} ->
        Logger.warn("FilterFunctions: luerl error: #{inspect(reason)}")
        {:error, :invalid_filter}
    end
  end
end
