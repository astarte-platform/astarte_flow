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

defmodule Astarte.Flow.Blocks.VirtualDevicePool do
  @moduledoc """
  This is a consumer block that takes `data` from incoming `Message`s and publishes it as an Astarte device,
  interpreting the `key` as <realm>/<device_id>/<interface><path>.

  The list of supported devices is configured using `start_link/1`.
  """

  use GenStage

  require Logger

  alias Astarte.Device
  alias Astarte.Flow.Message
  alias Astarte.Flow.VirtualDevicesSupervisor

  @doc """
  Starts the `VirtualDevicePool`.

  ## Options

    * `:pairing_url` (required) - URL of the Astarte Pairing API instance the devices will connect to, up to (and including) `/v1`.
    * `:devices` (required) - A list of supported devices, each represented by its `device_options` (see "Device options" below).
    * `:ignore_ssl_errors` - A boolean to indicate wether devices have to ignore SSL errors when connecting to the broker. Defaults to `false`.

  ## Device options
    * `:realm` (required)
    * `:device_id` (required)
    * `:credentials_secret` (required)
    * `:interface_provider` (required)

  See `Astarte.Device.start_link/1` for more documentation.
  """
  @spec start_link(options) :: GenServer.on_start()
        when options: [option],
             option:
               {:pairing_url, pairing_url :: String.t()}
               | {:devices, devices}
               | {:ignore_ssl_errors, ignore_ssl_errors :: boolean()},
             devices: [device_options],
             device_options: [device_option],
             device_option:
               {:realm, realm :: String.t()}
               | {:device_id, device_id :: String.t()}
               | {:credentials_secret, credentials_secret :: String.t()}
               | {:interface_provider, {module(), term()} | String.t()}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # Callbacks

  @impl true
  def init(opts) do
    pairing_url = Keyword.fetch!(opts, :pairing_url)
    devices = Keyword.fetch!(opts, :devices)
    ignore_ssl_errors = Keyword.get(opts, :ignore_ssl_errors, false)

    base_opts = [
      pairing_url: pairing_url,
      ignore_ssl_errors: ignore_ssl_errors
    ]

    with {:ok, devices} <- start_devices(base_opts, devices),
         :ok <- wait_for_device_connections(devices) do
      {:consumer, nil}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp start_devices(base_opts, devices) do
    full_device_options =
      for device_options <- devices do
        Keyword.merge(base_opts, device_options)
      end

    result =
      Enum.reduce_while(full_device_options, [], fn opts, acc ->
        case DynamicSupervisor.start_child(VirtualDevicesSupervisor, {Device, opts}) do
          {:ok, pid} ->
            {:cont, [pid | acc]}

          {:error, {:already_started, pid}} ->
            # Someone else is already using this device, but that's fine
            {:cont, [pid | acc]}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    case result do
      {:error, reason} ->
        {:error, reason}

      devices ->
        {:ok, devices}
    end
  end

  defp wait_for_device_connections(devices) do
    Enum.each(devices, fn device_pid ->
      Device.wait_for_connection(device_pid)
    end)
  end

  @impl true
  def handle_events(events, _from, state) do
    Enum.each(events, &handle_message/1)

    {:noreply, [], state}
  end

  defp handle_message(message) do
    %Message{
      key: key,
      data: data,
      timestamp: timestamp_micros
    } = message

    with {:ok, {realm, device_id, interface, path}} <- parse_key(key),
         {:ok, pid} <- fetch_device(realm, device_id),
         {:ok, timestamp} <- DateTime.from_unix(timestamp_micros, :microsecond),
         normalized_data = normalize_data(data),
         :ok <-
           Device.send_datastream(pid, interface, path, normalized_data, timestamp: timestamp) do
      :ok
    else
      {:error, reason} ->
        _ = Logger.warn("Error handling message: #{inspect(reason)}", message: message)
        {:error, reason}
    end
  end

  defp parse_key(key) do
    case String.split(key, "/") do
      [realm, device_id, interface | path_tokens] ->
        path = "/" <> Path.join(path_tokens)
        {:ok, {realm, device_id, interface, path}}

      _ ->
        {:error, :invalid_astarte_key}
    end
  end

  defp fetch_device(realm, device_id) do
    case Astarte.Device.get_pid(realm, device_id) do
      pid when is_pid(pid) ->
        {:ok, pid}

      nil ->
        {:error, :device_not_found}
    end
  end

  defp normalize_data(data) when is_map(data) do
    for {key, {_type, _subtype, value}} <- data, into: %{} do
      {key, value}
    end
  end

  defp normalize_data(data), do: data
end
