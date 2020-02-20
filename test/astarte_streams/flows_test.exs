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

defmodule Astarte.Flow.FlowsTest do
  use ExUnit.Case

  alias Astarte.Flow.Flows

  describe "flows" do
    setup [:cleanup_flows]

    alias Astarte.Flow.Flows.Flow
    alias Astarte.Flow.Flows.Supervisor, as: FlowsSupervisor

    @realm "test"
    @valid_attrs %{"name" => "test", "pipeline" => "test", "config" => %{"key" => "test"}}

    def flow_fixture(realm, attrs \\ %{}) do
      attrs =
        attrs
        |> Enum.into(@valid_attrs)

      {:ok, flow} = Flows.create_flow(realm, attrs)

      flow
    end

    defp cleanup_flows(_context) do
      on_exit(fn ->
        DynamicSupervisor.which_children(FlowsSupervisor)
        |> Enum.each(fn {_, pid, _, _} ->
          DynamicSupervisor.terminate_child(FlowsSupervisor, pid)
        end)

        # Wait a moment to ensure they all go down
        :timer.sleep(100)
      end)
    end

    test "list_flows/1 returns all flows" do
      flow = flow_fixture(@realm)
      assert Flows.list_flows(@realm) == [flow]
    end

    test "get_flow/2 returns the flow with given name" do
      flow = flow_fixture(@realm)
      assert {:ok, ^flow} = Flows.get_flow(@realm, flow.name)
    end

    test "get_flow/2 returns error with unexisting flow" do
      assert {:error, :not_found} = Flows.get_flow(@realm, "unexisting")
    end

    test "create_flow/2 with valid data creates a flow" do
      assert {:ok, %Flow{} = flow} = Flows.create_flow(@realm, @valid_attrs)

      [msg] = Flow.tap(@realm, flow.name) |> Enum.take(1)

      assert msg.key == @valid_attrs["config"]["key"]
    end

    test "create_flow/2 creates flows with different config" do
      assert {:ok, %Flow{} = flow} = Flows.create_flow(@realm, @valid_attrs)

      [msg] = Flow.tap(@realm, flow.name) |> Enum.take(1)

      assert msg.key == @valid_attrs["config"]["key"]

      attrs_other_key =
        @valid_attrs
        |> Map.put("config", %{"key" => "another"})
        |> Map.put("name", "other-flow")

      assert {:ok, %Flow{} = other_flow} = Flows.create_flow(@realm, attrs_other_key)

      [other_msg] = Flow.tap(@realm, other_flow.name) |> Enum.take(1)
      assert other_msg.key == "another"

      assert Flows.list_flows(@realm) |> length() == 2
    end

    test "create_flow/2 allows a flow with the same config in two different realms" do
      assert {:ok, %Flow{} = flow} = Flows.create_flow(@realm, @valid_attrs)

      assert {:ok, %Flow{} = flow2} = Flows.create_flow("otherrealm", @valid_attrs)

      assert Flows.list_flows("otherrealm") == [flow2]
    end

    test "create_flow/2 doesn't allow two flows with the same name in the same realm" do
      assert {:ok, %Flow{} = flow} = Flows.create_flow(@realm, @valid_attrs)
      assert {:error, %Ecto.Changeset{} = cs} = Flows.create_flow(@realm, @valid_attrs)
      assert cs.errors[:name] != nil
    end

    test "create_flow/2 with non-string name returns error changeset" do
      attrs = Map.put(@valid_attrs, "name", 42)
      assert {:error, %Ecto.Changeset{}} = Flows.create_flow(@realm, attrs)
    end

    test "create_flow/2 with invalid string name returns error changeset" do
      attrs = Map.put(@valid_attrs, "name", "no_underscores_allowed")
      assert {:error, %Ecto.Changeset{}} = Flows.create_flow(@realm, attrs)
    end

    test "create_flow/2 with invalid pipeline returns error changeset" do
      attrs = Map.put(@valid_attrs, "pipeline", 42)
      assert {:error, %Ecto.Changeset{}} = Flows.create_flow(@realm, attrs)
    end

    test "create_flow/2 with unexisting pipeline returns error changeset" do
      attrs = Map.put(@valid_attrs, "pipeline", "nonexisting")
      assert {:error, :pipeline_not_found} = Flows.create_flow(@realm, attrs)
    end

    test "delete_flow/2 deletes the flow" do
      flow = flow_fixture(@realm)
      assert :ok = Flows.delete_flow(@realm, flow)
      assert {:error, :not_found} = Flows.get_flow(@realm, flow.name)
    end

    test "delete_flow/2 returns an error for an unexisting flow" do
      assert {:error, :not_found} = Flows.delete_flow(@realm, %Flow{name: "nonexisting"})
    end
  end
end
