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

defmodule Astarte.Flow.Pipelines do
  require Logger

  def get_pipeline(realm, name) when is_binary(realm) and is_binary(name) do
    pipeline_file = Path.join(pipelines_dir(), name <> ".pipeline")

    with {:ok, pipeline_desc} <- File.read(pipeline_file) do
      {:ok, pipeline_desc}
    else
      _ ->
        _ = Logger.warn("Cannot read pipeline file #{pipeline_file}")
        {:error, :not_found}
    end
  end

  defp pipelines_dir do
    default = Application.app_dir(:astarte_flow, ["priv", "pipelines"])

    Application.get_env(:astarte_flow, :pipelines_dir, default)
  end
end
