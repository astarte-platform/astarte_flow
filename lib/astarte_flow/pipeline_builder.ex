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
  require Logger
  @moduledoc false

  alias Astarte.Flow.Blocks

  alias Astarte.Flow.Blocks.{
    Block,
    Container,
    DeviceEventsProducer,
    DynamicVirtualDevicePool,
    MapSplitter,
    VirtualDevicePool
  }

  alias Astarte.Flow.PipelineBuilder.Error

  alias ExJsonSchema.Validator
  alias Astarte.Flow.Config

  def parse(pipeline_desc) do
    with pipeline_charlist = String.to_charlist(pipeline_desc),
         {:ok, l, _} <- :pipelinelexer.string(pipeline_charlist) do
      :pipelineparser.parse(l)
    end
  end

  def build(realm, pipeline_desc, config \\ %{}) do
    maybe_blocks =
      with {:ok, parsed} <- parse(pipeline_desc) do
        Enum.map(parsed, fn {block, opts_list} ->
          opts = Enum.into(opts_list, %{})

          setup_block(realm, block, opts, config)
        end)
      end

    all_ok =
      Enum.all?(maybe_blocks, fn
        {:ok, _list} -> true
        {:error, _list} -> false
      end)

    if all_ok do
      built_pipeline = Enum.flat_map(maybe_blocks, fn {:ok, sub_blocks} -> sub_blocks end)
      {:ok, built_pipeline}
    else
      {:error, %Error{blocks: extract_errors(maybe_blocks)}}
    end
  end

  defp extract_errors(maybe_blocks) do
    Enum.reject(maybe_blocks, fn
      {:ok, _sub_blocks} -> true
      _ -> false
    end)
    |> Enum.map(fn {:error, {reason, blockname, details}} -> {blockname, {reason, details}} end)
  end

  defp setup_block(_realm, "astarte_devices_source", opts, config) do
    %{
      "realm" => realm,
      "amqp_exchange" => amqp_exchange
    } = opts

    evaluated_exchange = eval!(amqp_exchange, config)
    evaluated_realm = eval!(realm, config)

    amqp_routing_key = Map.get(opts, "amqp_routing_key", "")
    target_devices = Map.get(opts, "target_devices")

    # TODO: we should go for a proper validation system
    unless evaluated_exchange =~ ~r"^astarte_events_#{evaluated_realm}_[a-zA-Z0-9_\.\:]+$" do
      raise "exchange name not allowed"
    end

    {:ok,
     [
       {DeviceEventsProducer,
        [
          exchange: evaluated_exchange,
          routing_key: eval!(amqp_routing_key, config),
          realm: evaluated_realm,
          target_devices: eval!(target_devices, config),
          connection: Config.default_amqp_connection!(),
          prefetch_count: Config.default_amqp_prefetch_count!()
        ]}
     ]}
  end

  defp setup_block(_realm, "container", opts, config) do
    %{
      "image" => image
    } = opts

    # TODO: this should be auto-deduced by the position in the pipeline
    type =
      case Map.get(opts, "type", "producer_consumer") do
        "producer" -> :producer
        "producer_consumer" -> :producer_consumer
        "consumer" -> :consumer
        other -> raise "Invalid type in container block: #{inspect(other)}"
      end

    {:ok,
     [
       {Container,
        [
          image: eval!(image, config),
          type: type,
          connection: Config.default_amqp_connection!(),
          prefetch_count: Config.default_amqp_prefetch_count!()
        ]}
     ]}
  end

  defp setup_block(_realm, "split_map", opts, config) do
    key_action = eval!(Map.get(opts, "key_action", "replace"), config)
    delimiter = eval!(Map.get(opts, "delimiter", ""), config)
    fallback_action = eval!(Map.get(opts, "fallback_action", "pass_through"), config)
    fallback_key = eval!(Map.get(opts, "fallback_key", "fallback_key"), config)

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

    {:ok, [{MapSplitter, [key_action: key_action_opt, fallback_action: fallback_action_opt]}]}
  end

  # If it has target_devices, it's a normal VirtualDevicePool
  defp setup_block(_realm, "virtual_device_pool", %{"target_devices" => _} = opts, config) do
    alias Astarte.Device.SimpleInterfaceProvider

    %{
      "pairing_url" => pairing_url,
      "target_devices" => target_devices
    } = opts

    devices_array = eval!(target_devices, config)

    devices =
      for device_obj <- devices_array do
        %{
          "realm" => realm,
          "device_id" => device_id,
          "credentials_secret" => credentials_secret,
          "interfaces" => interfaces
        } = device_obj

        [
          device_id: eval!(device_id, config),
          realm: eval!(realm, config),
          credentials_secret: eval!(credentials_secret, config),
          interface_provider: {SimpleInterfaceProvider, interfaces: eval!(interfaces, config)}
        ]
      end

    {:ok, [{VirtualDevicePool, [pairing_url: eval!(pairing_url, config), devices: devices]}]}
  end

  # If it has interfaces in the top level, it's a DynamicVirtualDevicePool
  defp setup_block(_realm, "virtual_device_pool", %{"interfaces" => _} = opts, config) do
    alias Astarte.Device.SimpleInterfaceProvider

    pairing_url = Map.fetch!(opts, "pairing_url") |> eval!(config)
    realms = Map.fetch!(opts, "realms") |> eval!(config)
    interfaces = Map.fetch!(opts, "interfaces") |> eval!(config)

    pairing_jwt_map =
      Enum.into(realms, %{}, fn %{"realm" => realm, "jwt" => jwt} ->
        {eval!(realm, config), eval!(jwt, config)}
      end)

    opts = [
      pairing_url: pairing_url,
      pairing_jwt_map: pairing_jwt_map,
      interface_provider: {SimpleInterfaceProvider, interfaces: interfaces}
    ]

    {:ok, [{DynamicVirtualDevicePool, opts}]}
  end

  defp setup_block(realm, block_name, opts, config) do
    with {:ok, %Block{schema: schema} = block} <- Blocks.get_block(realm, block_name),
         resolved_schema = ExJsonSchema.Schema.resolve(schema),
         {:ok, evaluated_opts} <- evaluate_opts(opts, config),
         {:jsonschema, :ok} <- {:jsonschema, Validator.validate(resolved_schema, evaluated_opts)} do
      case block do
        %Block{beam_module: mod} when mod != nil ->
          {:ok, [{mod, opts_to_keyword_list(evaluated_opts)}]}

        %Block{source: source} when source != nil ->
          case build(realm, source, opts) do
            {:ok, blocks} ->
              {:ok, blocks}

            {:error, %Error{blocks: block_errors}} ->
              Logger.info("Failed to setup custom block due to nested block error.",
                tag: "internal_block_error"
              )

              {:error, {:internal_block_error, block_name, block_errors}}
          end
      end
    else
      {:error, :not_found} ->
        _ = Logger.info("Failed to setup unknown block.", tag: "unknown_block_error")
        {:error, {:unknown_block, block_name, "block is not supported or not installed."}}

      {:jsonschema, {:error, errors}} ->
        _ =
          Logger.info("Failed to setup block due to options error.",
            tag: "invalid_block_options_error"
          )

        {:error, {:invalid_block_options, block_name, errors}}

      {:error, {:json_path_multiple_values, path}} ->
        _ =
          Logger.info("Failed to setup block due to JSONPath which evaluated to multiple values.",
            tag: "json_path_multiple_values_error"
          )

        {:error,
         {:invalid_json_path, block_name, ~s[JSONPath "#{path}" evaluates to multiple values.]}}

      {:error, %ExJSONPath.ParsingError{message: message}} ->
        _ =
          Logger.info("Failed to setup block due to invalid JSONPath.",
            tag: "invalid_json_path_error"
          )

        {:error, {:invalid_json_path, block_name, message}}
    end
  end

  defp opts_to_keyword_list(opts) do
    Enum.map(opts, fn {k, v} ->
      {String.to_existing_atom(k), v}
    end)
  end

  defp evaluate_opts(opts, config) do
    Enum.reduce_while(opts, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      case eval(v, config) do
        {:error, reason} ->
          {:halt, {:error, reason}}

        {:ok, evaluated} ->
          {:cont, {:ok, Map.put(acc, k, evaluated)}}
      end
    end)
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

  def stream(realm, pipeline_string, config \\ %{}) do
    with {:ok, pipeline} <- build(realm, pipeline_string, config),
         {:ok, pids} <- start_all(pipeline) do
      pids
      |> List.first()
      |> List.wrap()
      |> GenStage.stream()
    end
  end

  defp eval({:json_path, path}, config) do
    case ExJSONPath.eval(config, path) do
      {:ok, [value]} ->
        {:ok, value}

      {:ok, values} when is_list(values) ->
        {:error, {:json_path_multiple_values, path}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp eval(any, _config) do
    {:ok, any}
  end

  defp eval!(any, config) do
    case eval(any, config) do
      {:ok, result} -> result
      _ -> raise "Invalid JSONPath."
    end
  end
end
