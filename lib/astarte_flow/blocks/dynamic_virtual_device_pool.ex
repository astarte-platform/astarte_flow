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

defmodule Astarte.Flow.Blocks.DynamicVirtualDevicePool do
  @moduledoc """
  This is a consumer block that takes `data` from incoming `Message`s and publishes it as an Astarte device,
  interpreting the `key` as <realm>/<device_id>/<interface><path>.

  The devices are dynamically registered when their device id is first seens. Credentials secret obtained
  with the registration are stored in the chosen CredentialsStorage.
  """

  use GenStage

  require Logger

  alias Astarte.API.Pairing
  alias Astarte.Device
  alias Astarte.Flow.Message
  alias Astarte.Flow.Blocks.DynamicVirtualDevicePool.DETSCredentialsStorage
  alias Astarte.Flow.VirtualDevicesSupervisor

  defmodule State do
    @moduledoc false

    defstruct [
      :device_base_opts,
      :credentials_storage,
      :pairing_agent,
      :pairing_jwt_map,
      :pairing_url
    ]
  end

  @doc """
  Starts the `DynamicVirtualDevicePool`.

  ## Options

    * `:pairing_url` (required) - URL of the Astarte Pairing API instance the devices will connect to, up to (and including) `/v1`.
    * `:pairing_jwt_map` (required) - A map in the form `%{realm_name => jwt}` where jwt must be a JWT with the authorizations needed
      to register a device in that realm.
    * `:interface_provider` (required) - The `interface_provider` that will be used by the spawned devices.
    * `:ignore_ssl_errors` - A boolean to indicate wether devices have to ignore SSL errors when connecting to the broker. Defaults to `false`.
    * `:credentials_storage` - The module used to store and fetch credentials secrets. Defaults to `DETSCredentialsStorage`.
    * `:pairing_agent` - The module used to register the devices. Defaults to `Astarte.API.Pairing.Agent` 
  """
  @spec start_link(options) :: GenServer.on_start()
        when options: [option],
             option:
               {:pairing_url, pairing_url :: String.t()}
               | {:pairing_jwt_map,
                  pairing_jwt_map :: %{optional(realm :: String.t()) => jwt :: String.t()}}
               | {:interface_provider, {module(), term()} | String.t()}
               | {:ignore_ssl_errors, ignore_ssl_errors :: boolean()}
               | {:credentials_storage, credentials_storage :: module()}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # Callbacks

  @impl true
  def init(opts) do
    pairing_url = Keyword.fetch!(opts, :pairing_url)
    pairing_jwt_map = Keyword.fetch!(opts, :pairing_jwt_map)
    interface_provider = Keyword.fetch!(opts, :interface_provider)
    ignore_ssl_errors = Keyword.get(opts, :ignore_ssl_errors, false)
    credentials_storage = Keyword.get(opts, :credentials_storage, DETSCredentialsStorage)
    pairing_agent = Keyword.get(opts, :pairing_agent, Pairing.Agent)

    base_opts = [
      pairing_url: pairing_url,
      interface_provider: interface_provider,
      ignore_ssl_errors: ignore_ssl_errors
    ]

    state = %State{
      credentials_storage: credentials_storage,
      pairing_agent: pairing_agent,
      pairing_url: pairing_url,
      pairing_jwt_map: pairing_jwt_map,
      device_base_opts: base_opts
    }

    {:consumer, state}
  end

  @impl true
  def handle_events(events, _from, state) do
    Enum.each(events, fn message ->
      handle_message(message, state)
    end)

    {:noreply, [], state}
  end

  defp handle_message(message, state) do
    %Message{
      key: key,
      data: data,
      timestamp: timestamp_micros
    } = message

    with {:ok, {realm, device_id, interface, path}} <- parse_key(key),
         {:ok, pid} <- fetch_device(state, realm, device_id),
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

  defp fetch_device(state, realm, device_id) do
    case Astarte.Device.get_pid(realm, device_id) do
      nil ->
        start_device(state, realm, device_id)

      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end

  defp start_device(state, realm, device_id) do
    %State{
      device_base_opts: base_opts
    } = state

    with {:ok, credentials_secret} <-
           fetch_credentials_secret(state, realm, device_id) do
      device_opts = [
        realm: realm,
        device_id: device_id,
        credentials_secret: credentials_secret
      ]

      opts = Keyword.merge(device_opts, base_opts)

      case DynamicSupervisor.start_child(VirtualDevicesSupervisor, {Device, opts}) do
        {:ok, pid} ->
          Device.wait_for_connection(pid)
          {:ok, pid}

        {:error, {:already_started, pid}} ->
          {:ok, pid}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_credentials_secret(state, realm, device_id) do
    %State{
      credentials_storage: credentials_storage
    } = state

    case credentials_storage.fetch_credentials_secret(realm, device_id) do
      {:ok, credentials_secret} ->
        {:ok, credentials_secret}

      :error ->
        register_device(state, realm, device_id)
    end
  end

  defp register_device(state, realm, device_id) do
    %State{
      credentials_storage: credentials_storage,
      pairing_agent: pairing_agent,
      pairing_jwt_map: pairing_jwt_map,
      pairing_url: pairing_url
    } = state

    with {:ok, jwt} <- Map.fetch(pairing_jwt_map, realm),
         client = Pairing.client(pairing_url, realm, auth_token: jwt),
         {:ok, %{status: 201, body: body}} <- pairing_agent.register_device(client, device_id),
         %{"data" => %{"credentials_secret" => credentials_secret}} <- body,
         :ok <-
           credentials_storage.store_credentials_secret(realm, device_id, credentials_secret) do
      {:ok, credentials_secret}
    else
      :error ->
        Logger.warn("No JWT available for realm #{realm}")

        {:error, :jwt_not_found}

      {:ok, %{status: status, body: body}} ->
        Logger.warn(
          "Cannot register device #{device_id} in realm #{realm}: " <>
            "#{inspect(status)} #{inspect(body)}"
        )

        {:error, :cannot_register_device}

      {:error, reason} ->
        Logger.warn(
          "Error registering device #{inspect(device_id)} in realm #{realm}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp normalize_data(data) when is_map(data) do
    for {key, {_type, _subtype, value}} <- data, into: %{} do
      {key, value}
    end
  end

  defp normalize_data(data), do: data
end
