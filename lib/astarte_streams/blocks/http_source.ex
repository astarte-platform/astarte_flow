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

defmodule Astarte.Streams.Blocks.HttpSource do
  @moduledoc """
  This is a producer block that generates messages by polling HTTP URLs with a GET request.

  It works by specifying a `base_url` and a list of `target_paths` to perform requests on.
  `HttpSource` will perform GET requests in a round robin fashion on all `target_paths`,
  waiting `polling_interval_ms` between two consecutive requests.

  If the request can't be performed or an error status (`>= 400`) is returned, no message
  is produced.

  If the request succeeds, `HttpSource` produces an `%Astarte.Streams.Message{}` containing
  these fields:
    * `key` contains the `target_path` of the request.
    * `data` contains the body of the response.
    * `type` is always `:binary`.
    * `subtype` is populated with the contents of the `content-type` HTTP header, defaulting
    to `"application/octet-stream"` if it's not found.
    * `metadata` contains the `"Astarte.Streams.Blocks.HttpSource.base_url"` key with `base_url`
    as value. Moreover, it contains all the HTTP headers contained in the response with
    their keys prefixed with `"Astarte.Streams.HttpSource."`.
    * `timestamp` contains the timestamp (in microseconds) the response was received.
  """

  use GenStage

  require Logger

  alias Astarte.Streams.Message

  @meta_namespace "Astarte.Streams.Blocks.HttpSource."

  defmodule State do
    @moduledoc false

    defstruct [
      :client,
      :base_url,
      :initial_target_paths,
      :target_paths,
      :polling_interval_ms,
      :pending_demand,
      :queue
    ]
  end

  @doc """
  Starts the `HttpSource`.

  ## Options

    * `:base_url` (required) - The base URL for the GET requests. This gets prepended to the `target_path` when
    performing a request.
    * `:target_paths` (required) - A non-empty list of target paths for GET requests.
    * `:polling_interval_ms` - The interval between two consecutive GET requests, in milliseconds. Defaults to 1000 ms.
    * `:headers` - A list of `{key, value}` tuples where `key` and `value` are `String` and represent
    headers to be set in the GET request.
  """
  @spec start_link(options) :: GenServer.on_start()
        when options: [option],
             option:
               {:base_url, url :: String.t()}
               | {:target_paths, target_paths :: nonempty_list(String.t())}
               | {:polling_interval_ms, polling_interval_ms :: number()}
               | {:headers, headers :: [{String.t(), String.t()}]}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # Callbacks

  @impl true
  def init(opts) do
    with {:url, {:ok, base_url}} <- {:url, Keyword.fetch(opts, :base_url)},
         {:paths, {:ok, target_paths}} <- {:paths, Keyword.fetch(opts, :target_paths)},
         polling_interval_ms = Keyword.get(opts, :polling_interval_ms, 1000),
         headers = Keyword.get(opts, :headers, []),
         :ok <- validate_target_paths(target_paths),
         :ok <- validate_headers(headers) do
      client = build_client(base_url, headers)

      state = %State{
        client: client,
        base_url: base_url,
        initial_target_paths: target_paths,
        target_paths: target_paths,
        polling_interval_ms: trunc(polling_interval_ms),
        pending_demand: 0,
        queue: :queue.new()
      }

      send(self(), :poll)

      {:producer, state, dispatcher: GenStage.BroadcastDispatcher}
    else
      {:url, _} ->
        {:stop, :missing_base_url}

      {:paths, _} ->
        {:stop, :missing_target_paths}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_demand(incoming_demand, %State{pending_demand: demand} = state) do
    dispatch_messages(%{state | pending_demand: demand + incoming_demand}, [])
  end

  @impl true
  def handle_info(:poll, %State{target_paths: []} = state) do
    # Finished all target_paths, start from the beginning
    handle_info(:poll, %{state | target_paths: state.initial_target_paths})
  end

  def handle_info(:poll, state) do
    %State{
      client: client,
      base_url: base_url,
      target_paths: [target_path | target_paths_tail],
      polling_interval_ms: polling_interval_ms,
      queue: queue
    } = state

    # Schedule next polling
    _ = Process.send_after(self(), :poll, polling_interval_ms)

    case get(client, target_path) do
      {:ok, response} ->
        new_queue =
          build_message(base_url, target_path, response)
          |> :queue.in(queue)

        new_state = %{state | target_paths: target_paths_tail, queue: new_queue}
        dispatch_messages(new_state, [])

      {:error, _reason} ->
        new_state = %{state | target_paths: target_paths_tail}
        {:noreply, [], new_state}
    end
  end

  defp get(client, target_path) do
    case Tesla.get(client, target_path) do
      {:ok, %{status: status} = response} when status < 400 ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        _ =
          Logger.warn("HttpSource received error status",
            status: status,
            body: body
          )

        {:error, :http_error_response}

      {:error, reason} ->
        _ = Logger.warn("HttpSource cannot make GET request", reason: reason)
        {:error, :request_failed}
    end
  end

  defp build_message(base_url, target_path, %Tesla.Env{body: body, headers: headers}) do
    {subtype, headers_metadata} = extract_headers(headers)

    metadata = Map.put(headers_metadata, @meta_namespace <> "base_url", base_url)

    timestamp =
      DateTime.utc_now()
      |> DateTime.to_unix(:microsecond)

    %Message{
      key: target_path,
      data: body,
      type: :binary,
      subtype: subtype,
      metadata: metadata,
      timestamp: timestamp
    }
  end

  defp extract_headers(headers) do
    Enum.reduce(headers, {"application/octet-stream", %{}}, fn
      {"content-type", subtype}, {_default_subtype, meta} ->
        {subtype, meta}

      {header, value}, {subtype, meta} ->
        prefixed_key = @meta_namespace <> header
        {subtype, Map.put(meta, prefixed_key, value)}
    end)
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

  defp validate_target_paths([]) do
    {:error, :empty_target_paths}
  end

  defp validate_target_paths(target_paths) when is_list(target_paths) do
    valid? = Enum.all?(target_paths, &String.starts_with?(&1, "/"))

    if valid? do
      :ok
    else
      {:error, :invalid_target_paths}
    end
  end

  defp validate_headers([]) do
    :ok
  end

  defp validate_headers([{key, value} | tail]) when is_binary(key) and is_binary(value) do
    validate_headers(tail)
  end

  defp validate_headers(_) do
    {:error, :invalid_headers}
  end

  defp build_client(base_url, headers) do
    middleware = [
      Tesla.Middleware.FollowRedirects,
      {Tesla.Middleware.BaseUrl, base_url},
      {Tesla.Middleware.Headers, headers}
    ]

    Tesla.client(middleware)
  end
end
