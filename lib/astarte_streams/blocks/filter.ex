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

defmodule Astarte.Streams.Blocks.Filter do
  alias Astarte.Streams.Blocks.FilterFunctions
  alias Astarte.Streams.Message

  defmodule Config do
    defstruct [
      :good_func
    ]
  end

  def initialize(initial_config) do
    with {:ok, func} <- FilterFunctions.make_filter(initial_config) do
      config = %Config{
        good_func: func
      }

      {:ok, config}
    end
  end

  def good?(%Config{} = config, %Message{} = message) do
    %Config{
      good_func: good_func
    } = config

    good_func.(message)
  end
end
