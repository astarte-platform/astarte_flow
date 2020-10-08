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

defmodule Astarte.Flow.Compat do
  @moduledoc """
  This module provides compatibility helpers to support multiple formats of configuration
  during the deprecation period.
  """

  require Logger

  # TODO: remove this when we remove the trailing `/v1` in `pairing_url` from all existing
  # pipelines/flows
  @doc """
  Removes the trailing `/v1` from a `pairing_url` if it finds one, printing a warning.
  """
  def normalize_device_pairing_url(pairing_url) when is_binary(pairing_url) do
    stripped_url = String.trim_trailing(pairing_url, "/")

    if String.ends_with?(stripped_url, "/v1") do
      _ =
        Logger.warn(
          "Found trailing /v1 in pairing_url: #{pairing_url}. " <>
            "The /v1 suffix is deprecated and will stop working in a future release. " <>
            "Please update your pipeline or flow configuration removing the /v1 suffix.",
          tag: "deprecated_pairing_url"
        )

      String.replace_trailing(stripped_url, "/v1", "")
    else
      pairing_url
    end
  end
end
