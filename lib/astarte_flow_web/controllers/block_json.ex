#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.FlowWeb.BlockJSON do
  alias Astarte.Flow.Blocks.Block

  @doc """
  Renders a list of blocks.
  """
  def index(%{blocks: blocks}) do
    %{data: for(block <- blocks, do: data(block))}
  end

  @doc """
  Renders a single block.
  """
  def show(%{block: block}) do
    %{data: data(block)}
  end

  defp data(%Block{} = %{beam_module: beam_module} = block) when not is_nil(beam_module) do
    # Default block
    %{
      name: block.name,
      beam_module: Atom.to_string(beam_module),
      type: block.type,
      schema: block.schema
    }
  end

  defp data(%Block{} = block) do
    # User block
    %{
      name: block.name,
      source: block.source,
      type: block.type,
      schema: block.schema
    }
  end
end
