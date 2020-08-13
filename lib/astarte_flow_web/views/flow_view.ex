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

defmodule Astarte.FlowWeb.FlowView do
  use Astarte.FlowWeb, :view
  alias Astarte.FlowWeb.FlowView
  alias Astarte.Flow.PipelineBuilder

  def render("index.json", %{flows: flows}) do
    %{data: render_many(flows, FlowView, "flow_name.json")}
  end

  def render("show.json", %{flow: flow}) do
    %{data: render_one(flow, FlowView, "flow.json")}
  end

  def render("flow.json", %{flow: flow}) do
    %{name: flow.name, pipeline: flow.pipeline, config: flow.config}
  end

  def render("flow_name.json", %{flow: flow}) do
    flow.name
  end

  def render("error.json", %{error: %PipelineBuilder.Error{blocks: blocks}}) do
    failures =
      Enum.map(blocks, fn
        {blockname, {:invalid_block_options, errors}} ->
          option_errors =
            Enum.map(errors, fn {message, option} ->
              %{option: option, message: message}
            end)

          %{block: blockname, error: "invalid_block_options", option_errors: option_errors}

        {blockname, {error, message}} when is_binary(message) ->
          %{block: blockname, error: error, message: message}
      end)

    %{errors: %{detail: "Failed pipeline instantiation", failures: failures}}
  end
end
