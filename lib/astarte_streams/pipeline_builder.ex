#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.Streams.PipelineBuilder do
  @moduledoc false

  alias Astarte.Streams.Blocks.{
    Filter,
    RandomProducer,
    JsonMapper,
    LuaMapper,
    MapSplitter,
    JsonPathMapper,
    HttpSource,
    HttpSink,
    VirtualDevicePool
  }

  def parse(pipeline_desc) do
    with pipeline_charlist = String.to_charlist(pipeline_desc),
         {:ok, l, _} <- :streamslexer.string(pipeline_charlist) do
      :streamsparser.parse(l)
    end
  end

  def build(pipeline_desc) do
    with {:ok, parsed} <- parse(pipeline_desc) do
      Enum.map(parsed, fn {block, opts_list} ->
        opts = Enum.into(opts_list, %{})

        setup_block(block, opts)
      end)
    end
  end

  defp setup_block("http_source", opts) do
    %{
      "base_url" => base_url,
      "target_paths" => target_paths,
      "polling_interval_ms" => polling_interval_ms,
      "authorization" => authorization_header
    } = opts

    {HttpSource,
     [
       base_url: base_url,
       target_paths: target_paths,
       polling_interval_ms: polling_interval_ms,
       headers: [{"Authorization", authorization_header}]
     ]}
  end

  defp setup_block("random_source", opts) do
    %{
      "key" => key,
      "min" => min,
      "max" => max
    } = opts

    {RandomProducer, [key: key, type: :real, min: min, max: max]}
  end

  defp setup_block("filter", opts) do
    %{
      "script" => script
    } = opts

    {Filter, [filter_config: %{operator: :luerl_script, script: script}]}
  end

  defp setup_block("http_sink", opts) do
    %{
      "url" => url
    } = opts

    {HttpSink, [url: url]}
  end

  defp setup_block("lua_map", opts) do
    %{
      "script" => script
    } = opts

    {LuaMapper, [script: script]}
  end

  defp setup_block("json_path_map", opts) do
    %{
      "template" => template
    } = opts

    {JsonPathMapper, [template: template]}
  end

  defp setup_block("split_map", opts) do
    key_action = Map.get(opts, "key_action", "replace")
    delimiter = Map.get(opts, "delimiter", "")
    fallback_action = Map.get(opts, "fallback_action", "pass_through")
    fallback_key = Map.get(opts, "fallback_key", "fallback_key")

    key_action_opt =
      case key_action do
        "none" -> :none
        "replace" -> :replace
        "append" -> {:append, delimiter}
        "prepend" -> {:prepend, delimiter}
      end

    fallback_action_opt =
      case fallback_action do
        "discard" -> :discard
        "replace_key" -> {:replace_key, fallback_key}
        "pass_through" -> :pass_through
      end

    {MapSplitter, [key_action: key_action_opt, fallback_action: fallback_action_opt]}
  end

  defp setup_block("to_json", _opts) do
    {JsonMapper, []}
  end

  defp setup_block("virtual_device_pool", opts) do
    %{
      "pairing_url" => pairing_url,
      "devices" => devices_array
    } = opts

    devices =
      for device_obj <- devices_array do
        %{
          "realm" => realm,
          "device_id" => device_id,
          "credentials_secret" => credentials_secret,
          "interfaces_directory" => interfaces_directory
        } = device_obj

        [
          device_id: device_id,
          realm: realm,
          credentials_secret: credentials_secret,
          interface_provider: interfaces_directory
        ]
      end

    {VirtualDevicePool, [pairing_url: pairing_url, devices: devices]}
  end

  def start_all(pipeline) do
    with {:ok, pids} <- start_link_all(pipeline) do
      pids
      |> Enum.reverse()
      |> connect_all()

      {:ok, pids}
    end
  end

  defp start_link_all(pipeline) do
    Enum.reduce_while(pipeline, {:ok, []}, fn {block_module, block_opts}, {:ok, acc} ->
      case block_module.start_link(block_opts) do
        {:ok, block_gs} ->
          {:cont, {:ok, [block_gs | acc]}}

        _any ->
          {:halt, {:error, :start_all_failed}}
      end
    end)
  end

  defp connect_all([h]) do
    h
  end

  defp connect_all([h | t]) do
    next = connect_all(t)
    GenStage.sync_subscribe(next, to: h)
    h
  end

  def stream(pipeline_string) do
    with pipeline = build(pipeline_string),
         {:ok, pids} <- start_all(pipeline) do
      pids
      |> List.first()
      |> List.wrap()
      |> GenStage.stream()
    end
  end
end
