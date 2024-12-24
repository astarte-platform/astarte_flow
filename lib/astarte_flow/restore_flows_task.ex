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

defmodule Astarte.Flow.RestoreFlowsTask do
  use Task, restart: :transient

  require Logger

  alias Astarte.Flow.Flows.DETSStorage
  alias Astarte.Flow.Flows.Flow
  alias Astarte.Flow.Flows.Supervisor, as: FlowsSupervisor

  @storage Application.get_env(:astarte_flow, :flows_storage_mod, DETSStorage)

  if Mix.env() == :test do
    # Fake task to avoid Flows from trying to be restored during tests
    def start_link(_arg) do
      Task.start_link(fn -> :ok end)
    end
  else
    def start_link(arg) do
      Task.start_link(__MODULE__, :run, [arg])
    end
  end

  def run(_arg) do
    for {realm, flow} <- @storage.get_all_flows do
      args = [realm: realm, flow: flow]

      case DynamicSupervisor.start_child(FlowsSupervisor, {Flow, args}) do
        {:ok, _pid} ->
          :ok

        {:error, {:already_started, _pid}} ->
          # It's ok, maybe the task was restarted after a crash
          :ok

        {:error, reason} ->
          Logger.warning(
            "Cannot start Flow #{inspect(flow.name)} in realm " <>
              "#{inspect(realm)}: #{inspect(reason)}."
          )

          raise "Cannot restore flows"
      end
    end

    :ok
  end
end
