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

defmodule Astarte.Streams.Flows do
  @moduledoc """
  The Flows context.
  """

  import Ecto.Query, warn: false
  alias Astarte.Streams.Repo

  alias Astarte.Streams.Flows.Flow

  @doc """
  Returns the list of flows.

  ## Examples

      iex> list_flows()
      [%Flow{}, ...]

  """
  def list_flows do
    raise "TODO"
  end

  @doc """
  Gets a single flow.

  Raises if the Flow does not exist.

  ## Examples

      iex> get_flow!(123)
      %Flow{}

  """
  def get_flow!(id), do: raise("TODO")

  @doc """
  Creates a flow.

  ## Examples

      iex> create_flow(%{field: value})
      {:ok, %Flow{}}

      iex> create_flow(%{field: bad_value})
      {:error, ...}

  """
  def create_flow(attrs \\ %{}) do
    raise "TODO"
  end

  @doc """
  Updates a flow.

  ## Examples

      iex> update_flow(flow, %{field: new_value})
      {:ok, %Flow{}}

      iex> update_flow(flow, %{field: bad_value})
      {:error, ...}

  """
  def update_flow(%Flow{} = flow, attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a Flow.

  ## Examples

      iex> delete_flow(flow)
      {:ok, %Flow{}}

      iex> delete_flow(flow)
      {:error, ...}

  """
  def delete_flow(%Flow{} = flow) do
    raise "TODO"
  end

  @doc """
  Returns a data structure for tracking flow changes.

  ## Examples

      iex> change_flow(flow)
      %Todo{...}

  """
  def change_flow(%Flow{} = flow) do
    raise "TODO"
  end
end
