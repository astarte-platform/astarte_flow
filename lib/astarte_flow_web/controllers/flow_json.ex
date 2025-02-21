#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.FlowWeb.FlowJSON do
  alias Astarte.Flow.Flows.Flow
  alias Astarte.Flow.PipelineBuilder

  @doc """
  Renders a list of flows.
  """
  def index(%{flows: flows}) do
    %{data: for(flow <- flows, do: flow_name(flow))}
  end

  @doc """
  Renders a single flow.
  """
  def show(%{flow: flow}) do
    %{data: data(flow)}
  end

  def error(%{error: %PipelineBuilder.Error{blocks: blocks}}) do
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

    {:error, failures: failures}
  end

  defp flow_name(%Flow{} = flow) do
    flow.name
  end

  defp data(%Flow{} = flow) do
    %{name: flow.name, pipeline: flow.pipeline, config: flow.config}
  end
end
