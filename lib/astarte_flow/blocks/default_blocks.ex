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

defmodule Astarte.Flow.Blocks.DefaultBlocks do
  alias Astarte.Flow.Blocks.Block

  # Recompile when the blocks directory changes
  @external_resource Path.expand("priv/blocks", __DIR__)

  Module.register_attribute(__MODULE__, :default_blocks, accumulate: true)

  default_blocks =
    "#{:code.priv_dir(:astarte_flow)}/blocks/*.json"
    |> Path.wildcard()

  for file <- default_blocks do
    %{"name" => name, "beam_module" => beam_module, "type" => type, "schema" => schema} =
      file
      |> File.read!()
      |> Jason.decode!()

    beam_module_atom = String.to_atom(beam_module)

    block = %Block{name: name, beam_module: beam_module_atom, type: type, schema: schema}

    # block is not a basic type, so it must be escaped to pass it to unquote
    escaped_block = Macro.escape(block)

    def fetch(unquote(name)) do
      {:ok, unquote(escaped_block)}
    end

    # Accumulate blocks
    @default_blocks block
  end

  # Fallback for non-existing blocks
  def fetch(_name) do
    {:error, :not_found}
  end

  def list do
    @default_blocks
  end
end
