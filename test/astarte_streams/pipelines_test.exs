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

defmodule Astarte.Flow.PipelinesTest do
  use ExUnit.Case

  alias Astarte.Flow.Pipelines
  alias Astarte.Flow.Pipelines.Pipeline

  @realm "test"

  describe "list_pipelines/1" do
    test "returns all pipelines" do
      assert Pipelines.list_pipelines(@realm) == [%Pipeline{name: "test"}]
    end
  end

  describe "get_pipeline/2" do
    test "returns the existing pipeline with given name" do
      assert {:ok, %Pipeline{name: "test", source: source}} =
               Pipelines.get_pipeline(@realm, "test")

      assert source =~ "random_source"
    end

    test "returns error with unexisting pipeline" do
      assert {:error, :not_found} = Pipelines.get_pipeline(@realm, "unexisting")
    end
  end
end
