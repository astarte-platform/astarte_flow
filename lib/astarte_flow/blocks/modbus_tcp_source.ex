#
# This file is part of Astarte.
#
# Copyright 2021 Ispirata Srl
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

defmodule Astarte.Flow.Blocks.ModbusTCPSource do
  @moduledoc """
  An Astarte Flow source that produces data by polling a Modbus device. This block
  is built to poll a single Modbus slave, if you want to poll multiple slaves you
  must instantiate multiple flows changing the slave id.

  The message contains these fields:
    * `key` contains the name defined in the configuration
    * `data` contains the data read from the Modbus device, converted with the format
    indicated in the configuration.
    * `type` depends on the format indicated in the configuration.
    * `metadata` contains the static metadata indicated in the configuration.
    * `timestamp` contains the timestamp (in microseconds) the message was polled on.

  Since polling happens at regular intervals while Flow works in a demand-driven
  way, this block implements a queue to buffer incoming messages while waiting
  for consumer demand.
  """

  use GenStage

  require Logger
  alias Astarte.Flow.Message
  alias Modbux.Tcp.Client, as: ModbusClient

  defmodule State do
    @moduledoc false

    defstruct [
      :modbus_connection,
      :slave_id,
      :targets_map,
      :polling_interval_ms,
      :pending_demand,
      :queue
    ]
  end

  @doc """
  Starts the `ModbusTCPSource`.

  ## Options
  * `host` (required): the IP address of the Modbus master this block will connect to.
  * `slave_id` (required): the slave id that will be polled.
  * `targets` (required): an array of maps representing the polling targets. See the section
  below for the structure of the map.
  * `port`: the TCP port. Defaults to 502, which is the standard Modbus TCP port.

  ## Target map
  Each map in the `targets` option must have this keys, with string keys:
  * `name` (required): the name of the measured quantity. This will be used as `key` in the
  resulting Flow Message
  * `base_address` (required): the address where the data starts. Depending on `format`, one
  or more registers will be read starting from this address.
  * `format` (required): one of `:int16`, `:uint16`, `:float32be`, `:float32le`, `:boolean`.
  The `be` and `le` suffix in `float32` format indicates the endianness, i.e. the order of
  the two 16 bits halves.
  * `modbus_type` (required): one of `:coil`, `:discrete_input`, `:input_register`,
  `:holding_register`.
  * `polling_interval_ms` (required): the interval between two polling on this target. Must be
  > 1000. *Caveat*: currently this block only supports setting the same `polling_interval_ms`
  for all targets, this limitation will be removed in a future release.
  * `static_metadata`: a map containing some static metadata that will be added to the message
  in the `metadata` field. It can be used to add information (e.g. units of measurement).
  """
  @spec start_link(opts) :: GenServer.on_start()
        when opts: [opt],
             opt:
               {:host, String.t()}
               | {:port, integer()}
               | {:slave_id, integer()}
               | {:targets, nonempty_list(map())}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # GenStage callbacks

  @impl true
  def init(opts) do
    with {:ok, conn_opts} <- build_connection_opts(opts),
         {:ok, slave_id} <- fetch_slave_id(opts),
         {:ok, targets_map} <- build_targets_map(opts),
         {:ok, pid} <- ModbusClient.start_link(conn_opts),
         :ok <- ModbusClient.connect(pid) do
      # TODO: for now we use a single polling interval
      polling_interval_ms = get_polling_interval_ms(targets_map)

      state = %State{
        modbus_connection: pid,
        slave_id: slave_id,
        targets_map: targets_map,
        polling_interval_ms: polling_interval_ms,
        pending_demand: 0,
        queue: :queue.new()
      }

      # Kickoff the polling
      send(self(), :poll)

      {:producer, state, dispatcher: GenStage.BroadcastDispatcher}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_demand(incoming_demand, %State{pending_demand: demand} = state) do
    dispatch_messages(%{state | pending_demand: demand + incoming_demand}, [])
  end

  @impl true
  def handle_cast({:new_message, %Message{} = message}, state) do
    %State{
      queue: queue
    } = state

    updated_queue = :queue.in(message, queue)
    dispatch_messages(%{state | queue: updated_queue}, [])
  end

  @impl true
  def handle_info(:poll, state) do
    %State{
      modbus_connection: pid,
      slave_id: slave_id,
      polling_interval_ms: polling_interval_ms,
      targets_map: targets_map
    } = state

    Enum.each(targets_map, fn {address, %{format: format, read_command: cmd_id}} ->
      count = format_to_count(format)
      cmd = {cmd_id, slave_id, address, count}
      # TODO: for now we expect a valid request, so reconnection is handled
      # by crash + supervision. We should probably handle this more gracefully in
      # the future
      :ok = ModbusClient.request(pid, cmd)
    end)

    # Fire polling again in a bit
    :timer.send_after(polling_interval_ms, :poll)

    {:noreply, [], state}
  end

  def handle_info({:modbus_tcp, {_cmd, _slave_id, address, _count}, values}, state) do
    %State{
      targets_map: targets_map,
      queue: queue
    } = state

    with {:ok, target} <- Map.fetch(targets_map, address),
         {:ok, message} <- build_message(values, target) do
      updated_queue = :queue.in(message, queue)
      dispatch_messages(%{state | queue: updated_queue}, [])
    else
      :error ->
        _ = Logger.warn("Received data for unknown target address: #{address}")
        {:noreply, [], state}

      {:error, reason} ->
        _ = Logger.warn("Error generating message from Modbus data: #{reason}")
        {:noreply, [], state}
    end
  end

  defp build_message(values, %{format: format, name: name} = target) do
    with {:ok, data} <- convert_values(values, format) do
      timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
      type = format_to_type(format)
      metadata = Map.get(target, :static_metadata, %{})

      message = %Message{
        key: name,
        data: data,
        type: type,
        metadata: metadata,
        timestamp: timestamp
      }

      {:ok, message}
    end
  end

  defp convert_values([value], :int16) do
    <<signed_value::integer-signed-size(16)>> = :binary.encode_unsigned(value)
    {:ok, signed_value}
  end

  defp convert_values([value], :uint16) do
    {:ok, value}
  end

  defp convert_values([value], :boolean) do
    if value == 0 do
      {:ok, false}
    else
      {:ok, true}
    end
  end

  defp convert_values([_v1, _v2] = values, :float32be) do
    float_value = Modbux.IEEE754.from_2_regs(values, :be)
    {:ok, float_value}
  end

  defp convert_values([_v1, _v2] = values, :float32le) do
    float_value = Modbux.IEEE754.from_2_regs(values, :le)
    {:ok, float_value}
  end

  defp convert_values(values, format) do
    Logger.warn("Invalid conversion, values: #{inspect(values)}, format: #{inspect(format)}")
    {:error, :invalid_conversion}
  end

  defp format_to_count(format) do
    case format do
      :int16 -> 1
      :uint16 -> 1
      :float32be -> 2
      :float32le -> 2
      :boolean -> 1
    end
  end

  defp format_to_type(format) do
    case format do
      :int16 -> :integer
      :uint16 -> :integer
      :float32be -> :real
      :float32le -> :real
      :boolean -> :boolean
    end
  end

  defp build_connection_opts(opts) do
    with {:ok, ip} <- fetch_ip(opts),
         {:ok, port} <- fetch_port(opts) do
      opts = [
        active: true,
        ip: ip,
        tcp_port: port
      ]

      {:ok, opts}
    end
  end

  defp fetch_ip(opts) do
    with {:ok, host_string} <- Keyword.fetch(opts, :host),
         host_charlist = to_charlist(host_string),
         {:ok, parsed_ip} <- :inet.parse_address(host_charlist) do
      {:ok, parsed_ip}
    else
      :error ->
        {:error, :missing_host}

      {:error, :einval} ->
        {:error, :invalid_host_ip}
    end
  end

  defp fetch_port(opts) do
    case Keyword.get(opts, :port, 502) do
      port when is_integer(port) and port >= 1 and port <= 65535 ->
        {:ok, port}

      _ ->
        {:error, :invalid_port}
    end
  end

  defp fetch_slave_id(opts) do
    case Keyword.fetch(opts, :slave_id) do
      {:ok, slave_id} when is_integer(slave_id) and slave_id >= 1 and slave_id <= 247 ->
        {:ok, slave_id}

      :error ->
        {:error, :missing_slave_id}

      _ ->
        {:error, :invalid_slave_id}
    end
  end

  defp build_targets_map(opts) do
    with {:ok, targets_config} when targets_config != [] <- Keyword.fetch(opts, :targets),
         {:ok, targets} <- convert_targets(targets_config),
         targets_map = Enum.into(targets, %{}),
         # TODO: temporary check to ensure all targets have the same polling interval
         :ok <- check_polling_interval(targets_map) do
      {:ok, targets_map}
    else
      :error ->
        {:error, :missing_targets}

      # Empty targets
      {:ok, []} ->
        {:error, :empty_targets}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_polling_interval(targets_map) do
    [%{polling_interval_ms: first_interval} | tail] = Map.values(targets_map)

    all_intervals_equal =
      Enum.all?(tail, fn %{polling_interval_ms: interval} -> interval == first_interval end)

    if all_intervals_equal do
      :ok
    else
      {:error, :polling_intervals_must_be_equal}
    end
  end

  defp convert_targets(targets_config) do
    Enum.reduce_while(targets_config, {:ok, []}, fn target, {:ok, acc} ->
      with {:ok, address} <- Map.fetch(target, "base_address"),
           {:ok, target_value} <- build_target(target) do
        entry = {address, target_value}
        {:cont, {:ok, [entry | acc]}}
      else
        :error ->
          {:halt, {:error, :missing_base_address}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp build_target(target_config) do
    with {:name, {:ok, name}} <- {:name, Map.fetch(target_config, "name")},
         {:format, {:ok, format}} <- {:format, Map.fetch(target_config, "format")},
         {:ok, format_atom} <- cast_format(format),
         {:modbus_type, {:ok, modbus_type}} <-
           {:modbus_type, Map.fetch(target_config, "modbus_type")},
         {:ok, read_command} <- get_read_command(modbus_type),
         {:polling_interval, {:ok, polling_interval}} <-
           {:polling_interval, Map.fetch(target_config, "polling_interval_ms")} do
      static_metadata = Map.get(target_config, "static_metadata")

      target = %{
        name: name,
        format: format_atom,
        static_metadata: static_metadata,
        read_command: read_command,
        polling_interval_ms: polling_interval
      }

      {:ok, target}
    else
      {:name, :error} ->
        {:error, :missing_name_in_target}

      {:format, :error} ->
        {:error, :missing_format_in_target}

      {:modbus_type, :error} ->
        {:error, :missing_modbus_type_in_target}

      {:polling_interval, :error} ->
        {:error, :missing_polling_interval_in_target}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cast_format(format) do
    case format do
      "int16" -> {:ok, :int16}
      "uint16" -> {:ok, :uint16}
      "float32be" -> {:ok, :float32be}
      "float32le" -> {:ok, :float32le}
      _ -> {:error, :invalid_format}
    end
  end

  defp get_read_command(modbus_type) do
    case modbus_type do
      "coil" -> {:ok, :rc}
      "discrete_input" -> {:ok, :ri}
      "input_register" -> {:ok, :rir}
      "holding_register" -> {:ok, :rhr}
      _ -> {:error, :invalid_modbus_type}
    end
  end

  defp get_polling_interval_ms(targets_map) do
    # TODO: right now the targets are guaranteed to have all the same polling interval
    # so we just take the first one
    Map.values(targets_map)
    |> hd()
    |> Map.fetch!(:polling_interval_ms)
  end

  defp dispatch_messages(%State{pending_demand: 0} = state, messages) do
    {:noreply, Enum.reverse(messages), state}
  end

  defp dispatch_messages(%State{pending_demand: demand, queue: queue} = state, messages) do
    case :queue.out(queue) do
      {{:value, message}, updated_queue} ->
        updated_state = %{state | pending_demand: demand - 1, queue: updated_queue}
        updated_messages = [message | messages]

        dispatch_messages(updated_state, updated_messages)

      {:empty, _queue} ->
        {:noreply, Enum.reverse(messages), state}
    end
  end
end
