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

defmodule Astarte.Flow.Flows do
  @moduledoc """
  The Flows context.
  """

  alias Astarte.Flow.Flows.Flow
  alias Astarte.Flow.Flows.Registry, as: FlowsRegistry
  alias Astarte.Flow.Flows.RealmRegistry
  alias Astarte.Flow.Flows.Supervisor, as: FlowsSupervisor
  require Logger

  @doc """
  Returns the list of flows for a realm.
  """
  def list_flows(realm) do
    Registry.lookup(RealmRegistry, realm)
    |> Enum.map(fn {_pid, name} -> name end)
  end

  @doc """
  Gets a single flow.

  Returns `{:error, :not_found}` if the flow does not exist.
  """
  def get_flow(realm, name) do
    case Registry.lookup(FlowsRegistry, {realm, name}) do
      [] ->
        {:error, :not_found}

      [{pid, nil}] ->
        {:ok, Flow.get_flow(pid)}
    end
  end

  @doc """
  Creates a flow.

  ## Examples

      iex> create_flow(%{field: value})
      {:ok, %Flow{}}

      iex> create_flow(%{field: bad_value})
      {:error, ...}

  """
  def create_flow(realm, attrs) do
    changeset = Flow.changeset(%Flow{}, attrs)

    with {:ok, %Flow{} = flow} <- Ecto.Changeset.apply_action(changeset, :insert),
         args = [realm: realm, flow: flow],
         {:ok, _pid} <- DynamicSupervisor.start_child(FlowsSupervisor, {Flow, args}) do
      {:ok, flow}
    else
      {:error, {:already_started, _pid}} ->
        {:error, Ecto.Changeset.add_error(changeset, :name, "is already taken")}

      {:error, other} ->
        {:error, other}
    end
  end

  @doc """
  Deletes a Flow.

  ## Examples

      iex> delete_flow(flow)
      {:ok, %Flow{}}

      iex> delete_flow(flow)
      {:error, ...}

  """
  def delete_flow(realm, %Flow{name: name}) do
    with [{pid, nil}] <- Registry.lookup(FlowsRegistry, {realm, name}) do
      DynamicSupervisor.terminate_child(FlowsSupervisor, pid)
    else
      [] ->
        {:error, :not_found}
    end
  end
end
