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

  import Mox

  describe "flows" do
    setup [:cleanup_flows, :populate_pipelines]

    alias Astarte.Flow.Flows.Flow
    alias Astarte.Flow.Flows.Supervisor, as: FlowsSupervisor

    @realm "test"
    @valid_attrs %{"name" => "test", "pipeline" => "test", "config" => %{"key" => "test"}}

    def flow_fixture(realm, attrs \\ %{}) do
      FlowsStorageMock
      |> expect(:insert_flow, fn ^realm, _flow ->
        :ok
      end)

      attrs =
        attrs
        |> Enum.into(@valid_attrs)

      {:ok, flow} = Flows.create_flow(realm, attrs)

      # Make sure it's created, since it's an async operation
      :ok = wait_for_flow_creation(realm, flow.name)

      flow
    end

    # Waits up to 5_000 ms for flow creation
    defp wait_for_flow_creation(realm, name) do
      start =
        DateTime.utc_now()
        |> DateTime.to_unix(:millisecond)

      wait_for_flow_creation(realm, name, start, start)
    end

    defp wait_for_flow_creation(_realm, _name, start, now) when now > start + 5_000 do
      {:error, :timeout}
    end

    defp wait_for_flow_creation(realm, name, start, _now) do
      case Flows.get_flow(realm, name) do
        {:ok, _pid} ->
          :ok

        {:error, :not_found} ->
          # Sleep a little to avoid busy waiting
          :timer.sleep(100)

          now =
            DateTime.utc_now()
            |> DateTime.to_unix(:millisecond)

          wait_for_flow_creation(realm, name, start, now)
      end
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

    defp populate_pipelines(context) do
      set_mox_global(context)

      PipelinesStorageMock
      |> stub(:fetch_pipeline, fn
        @realm, "test" ->
          alias Astarte.Flow.Pipelines.Pipeline

          source = "random_source.key(${$.config.key}).min(0).max(100)"
          pipeline = %Pipeline{name: "test", source: source, description: ""}

          {:ok, pipeline}

        "otherrealm", "test" ->
          alias Astarte.Flow.Pipelines.Pipeline

          source = "random_source.key(${$.config.key}).min(0).max(100)"
          pipeline = %Pipeline{name: "test", source: source, description: ""}

          {:ok, pipeline}

        @realm, "nonexisting" ->
          {:error, :not_found}
      end)

      :ok
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
      FlowsStorageMock
      |> expect(:insert_flow, fn @realm, flow ->
        assert flow.name == @valid_attrs["name"]
        assert flow.pipeline == @valid_attrs["pipeline"]
        assert flow.config == @valid_attrs["config"]

        :ok
      end)

      assert {:ok, %Flow{} = flow} = Flows.create_flow(@realm, @valid_attrs)

      [msg] = Flow.tap(@realm, flow.name) |> Enum.take(1)

      assert msg.key == @valid_attrs["config"]["key"]
    end

    test "create_flow/2 creates flows with different config" do
      FlowsStorageMock
      |> expect(:insert_flow, fn @realm, flow ->
        assert flow.name == @valid_attrs["name"]
        assert flow.pipeline == @valid_attrs["pipeline"]
        assert flow.config == @valid_attrs["config"]

        :ok
      end)

      assert {:ok, %Flow{} = flow} = Flows.create_flow(@realm, @valid_attrs)

      [msg] = Flow.tap(@realm, flow.name) |> Enum.take(1)

      assert msg.key == @valid_attrs["config"]["key"]

      attrs_other_key =
        @valid_attrs
        |> Map.put("config", %{"key" => "another"})
        |> Map.put("name", "other-flow")

      FlowsStorageMock
      |> expect(:insert_flow, fn @realm, flow ->
        assert flow.name == "other-flow"
        assert flow.config["key"] == "another"

        :ok
      end)

      assert {:ok, %Flow{} = other_flow} = Flows.create_flow(@realm, attrs_other_key)

      [other_msg] = Flow.tap(@realm, other_flow.name) |> Enum.take(1)
      assert other_msg.key == "another"

      assert Flows.list_flows(@realm) |> length() == 2
    end

    test "create_flow/2 allows a flow with the same config in two different realms" do
      FlowsStorageMock
      |> expect(:insert_flow, fn @realm, flow ->
        assert flow.name == @valid_attrs["name"]
        assert flow.pipeline == @valid_attrs["pipeline"]
        assert flow.config == @valid_attrs["config"]

        :ok
      end)
      |> expect(:insert_flow, fn "otherrealm", flow ->
        assert flow.name == @valid_attrs["name"]
        assert flow.pipeline == @valid_attrs["pipeline"]
        assert flow.config == @valid_attrs["config"]

        :ok
      end)

      assert {:ok, %Flow{} = flow} = Flows.create_flow(@realm, @valid_attrs)

      assert {:ok, %Flow{} = flow2} = Flows.create_flow("otherrealm", @valid_attrs)

      assert Flows.list_flows("otherrealm") == [flow2]
    end

    test "create_flow/2 doesn't allow two flows with the same name in the same realm" do
      FlowsStorageMock
      |> expect(:insert_flow, fn @realm, flow ->
        assert flow.name == @valid_attrs["name"]
        assert flow.pipeline == @valid_attrs["pipeline"]
        assert flow.config == @valid_attrs["config"]

        :ok
      end)

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

      FlowsStorageMock
      |> expect(:delete_flow, fn realm, name ->
        assert realm == @realm
        assert flow.name == name

        :ok
      end)

      assert :ok = Flows.delete_flow(@realm, flow)
      assert {:error, :not_found} = Flows.get_flow(@realm, flow.name)
    end

    test "delete_flow/2 returns an error for an unexisting flow" do
      FlowsStorageMock
      |> stub(:delete_flow, fn @realm, _name ->
        :ok
      end)

      assert {:error, :not_found} = Flows.delete_flow(@realm, %Flow{name: "nonexisting"})
    end
  end
end
