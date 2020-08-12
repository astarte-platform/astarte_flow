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

defmodule Astarte.Flow.Blocks.Block do
  use Ecto.Schema
  import Ecto.Changeset

  alias Astarte.Flow.Blocks.Block
  alias Astarte.Flow.PipelineBuilder
  alias ExJsonSchema.Validator
  alias ExJsonSchema.Schema.Draft4

  @block_name_format ~r/^[a-zA-Z][a-zA-Z0-9-_]*$/

  @primary_key false
  @derive {Phoenix.Param, key: :name}
  embedded_schema do
    field :name, :string
    field :beam_module, :any, virtual: true
    field :source, :string
    field :type, :string
    field :schema, :map, default: %{}
  end

  @doc false
  def changeset(%Block{} = block, attrs) do
    block
    |> cast(attrs, [:name, :source, :type, :schema])
    |> validate_required([:name, :source, :type, :schema])
    |> validate_format(:name, @block_name_format)
    |> validate_inclusion(:type, ~w(producer consumer producer_consumer))
    |> validate_source(:source)
    |> validate_schema(:schema)
  end

  defp validate_source(changeset, field) do
    # TODO: we should also check that the pipeline doesn't include producers and consumers
    validate_change(changeset, field, fn field, source ->
      case PipelineBuilder.parse(source) do
        {:ok, _} -> []
        {:error, _} -> [{field, "is not valid"}]
      end
    end)
  end

  defp validate_schema(changeset, field) do
    validate_change(changeset, field, fn field, schema ->
      case Validator.validate(Draft4.schema(), schema) do
        :ok ->
          []

        {:error, errors} ->
          [{field, {"is not a valid JSON Schema", validator_errors: errors}}]
      end
    end)
  end
end
