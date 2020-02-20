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

defmodule Astarte.Flow.Pipelines.Pipeline do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Flow.Pipelines.Pipeline

  @primary_key false
  @derive {Phoenix.Param, key: :name}
  embedded_schema do
    field :description, :string
    field :name, :string
    field :source, :string
  end

  @doc false
  def changeset(%Pipeline{} = pipeline, attrs) do
    pipeline
    |> cast(attrs, [:name, :description, :source])
    |> validate_required([:name, :description, :source])
  end
end
