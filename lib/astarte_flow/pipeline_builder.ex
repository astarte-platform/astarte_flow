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

defmodule Astarte.Flow.PipelineBuilder do
  @moduledoc false

  alias Astarte.Flow.Blocks.{
    Container,
    DeviceEventsProducer,
    Filter,
    RandomProducer,
    JsonMapper,
    LuaMapper,
    MapSplitter,
    JsonPathMapper,
    HttpSource,
    HttpSink,
    Sorter,
    VirtualDevicePool
  }

  def parse(pipeline_desc) do
    with pipeline_charlist = String.to_charlist(pipeline_desc),
         {:ok, l, _} <- :pipelinelexer.string(pipeline_charlist) do
      :pipelineparser.parse(l)
    end
  end

  def build(pipeline_desc, config \\ %{}) do
    with {:ok, parsed} <- parse(pipeline_desc) do
      Enum.map(parsed, fn {block, opts_list} ->
        opts = Enum.into(opts_list, %{})

        setup_block(block, opts, config)
      end)
    end
  end

  defp setup_block("astarte_devices_source", _opts, _config) do
    {DeviceEventsProducer,
     [
       routing_key: "trigger_engine",
       connection: Application.fetch_env!(:astarte_flow, :default_amqp_connection)
     ]}
  end

  defp setup_block("container", opts, config) do
    %{
      "image" => image
    } = opts

    {Container,
     [
       image: eval(image, config),
       connection: Application.fetch_env!(:astarte_flow, :default_amqp_connection)
     ]}
  end

  defp setup_block("http_source", opts, config) do
    %{
      "base_url" => base_url,
      "target_paths" => target_paths,
      "polling_interval_ms" => polling_interval_ms,
      "authorization" => authorization_header
    } = opts

    {HttpSource,
     [
       base_url: eval(base_url, config),
       target_paths: eval(target_paths, config),
       polling_interval_ms: eval(polling_interval_ms, config),
       headers: [{"Authorization", eval(authorization_header, config)}]
     ]}
  end

  defp setup_block("random_source", opts, config) do
    %{
      "key" => key,
      "min" => min,
      "max" => max
    } = opts

    {RandomProducer,
     [key: eval(key, config), type: :real, min: eval(min, config), max: eval(max, config)]}
  end

  defp setup_block("filter", opts, config) do
    %{
      "script" => script
    } = opts

    {Filter, [filter_config: %{operator: :luerl_script, script: eval(script, config)}]}
  end

  defp setup_block("http_sink", opts, config) do
    %{
      "url" => url
    } = opts

    {HttpSink, [url: eval(url, config)]}
  end

  defp setup_block("lua_map", opts, config) do
    %{
      "script" => script
    } = opts

    {LuaMapper, [script: eval(script, config)]}
  end

  defp setup_block("json_path_map", opts, config) do
    %{
      "template" => template
    } = opts

    {JsonPathMapper, [template: eval(template, config)]}
  end

  defp setup_block("sort", opts, _config) do
    %{} = opts

    {Sorter, []}
  end

  defp setup_block("split_map", opts, config) do
    key_action = eval(Map.get(opts, "key_action", "replace"), config)
    delimiter = eval(Map.get(opts, "delimiter", ""), config)
    fallback_action = eval(Map.get(opts, "fallback_action", "pass_through"), config)
    fallback_key = eval(Map.get(opts, "fallback_key", "fallback_key"), config)

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

  defp setup_block("to_json", _opts, _config) do
    {JsonMapper, []}
  end

  defp setup_block("virtual_device_pool", opts, config) do
    %{
      "pairing_url" => pairing_url,
      "devices" => devices
    } = opts

    devices_array = eval(devices, config)

    devices =
      for device_obj <- devices_array do
        %{
          "realm" => realm,
          "device_id" => device_id,
          "credentials_secret" => credentials_secret,
          "interfaces_directory" => interfaces_directory
        } = device_obj

        [
          device_id: eval(device_id, config),
          realm: eval(realm, config),
          credentials_secret: eval(credentials_secret, config),
          interface_provider: eval(interfaces_directory, config)
        ]
      end

    {VirtualDevicePool, [pairing_url: eval(pairing_url, config), devices: devices]}
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

  def stream(pipeline_string, config \\ %{}) do
    with pipeline = build(pipeline_string, config),
         {:ok, pids} <- start_all(pipeline) do
      pids
      |> List.first()
      |> List.wrap()
      |> GenStage.stream()
    end
  end

  defp eval({:json_path, path}, config) do
    ExJsonPath.eval(config, path)
  end

  defp eval(any, _config) do
    any
  end
end
