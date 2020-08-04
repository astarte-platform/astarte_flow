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

defmodule Astarte.FlowWeb.PipelineView do
  use Astarte.FlowWeb, :view

  alias Astarte.FlowWeb.PipelineView

  def render("index.json", %{pipelines: pipelines}) do
    %{data: render_many(pipelines, PipelineView, "pipeline_name.json")}
  end

  def render("show.json", %{pipeline: pipeline}) do
    %{data: render_one(pipeline, PipelineView, "pipeline.json")}
  end

  def render("pipeline.json", %{pipeline: pipeline}) do
    %{
      name: pipeline.name,
      source: pipeline.source,
      description: pipeline.description,
      schema: pipeline.schema || %{}
    }
  end

  def render("pipeline_name.json", %{pipeline: pipeline}) do
    pipeline.name
  end
end
