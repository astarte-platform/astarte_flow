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

defmodule Astarte.Streams.Flows.Flow do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Streams.Flows.Flow

  @primary_key false
  @derive {Phoenix.Param, key: :name}
  embedded_schema do
    field :config, :map
    field :name, :string
    field :pipeline, :string
  end

  @doc false
  def changeset(%Flow{} = flow, attrs) do
    flow
    |> cast(attrs, [:pipeline, :name, :config])
    |> validate_required([:pipeline, :name, :config])
  end
end
