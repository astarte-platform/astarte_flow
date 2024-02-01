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

defmodule Astarte.Flow.Blocks.HttpSink do
  @moduledoc """
  This is a consumer block that takes `data` from incoming `Message` and makes a POST request
  to the configured URL containing `data`. This block supports only incoming messages with type `:binary`,
  so serialization to binary format must be handled in a separate block before the message arrives here.
  The `subtype` of the message, if present, is added as `Content-Type` header.
  Additionally, static headers can be added to the POST requests with the initial configuration.

  For the time being, the delivery is best-effort (i.e. if a message is not delivered, it is discarded).
  """

  use GenStage

  require Logger

  alias Astarte.Flow.Message

  defmodule Config do
    @moduledoc false

    @type t() :: %__MODULE__{
            client: Tesla.Client.t()
          }

    defstruct [
      :client
    ]
  end

  @doc """
  Starts the `HttpSink`.

  ## Options

    * `:url` (required) - The target URL for the POST request.
    * `:headers` - A list of `{key, value}` tuples where `key` and `value` are `String` and represent
    headers to be set in the POST request.
    * `:ignore_ssl_errors` - If `true`, ignore SSL errors that happen while performing the request.
    Defaults to `false`.
  """
  @spec start_link(options) :: GenServer.on_start()
        when options: [option],
             option:
               {:url, url :: String.t()}
               | {:headers, headers :: [{String.t(), String.t()}]}
  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  # Callbacks

  @impl true
  def init(opts) do
    url = Keyword.fetch!(opts, :url)
    headers = Keyword.get(opts, :headers, [])

    with :ok <- validate_headers(headers) do
      client = build_client(url, opts)

      {:consumer, %Config{client: client}}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_events(events, _from, %Config{client: client} = config) do
    for %Message{data: data, type: type, subtype: subtype} <- events,
        type == :binary or type == :string do
      opts =
        if String.valid?(subtype) do
          [headers: [{"content-type", subtype}]]
        else
          []
        end

      _ = post(client, data, opts)
    end

    {:noreply, [], config}
  end

  defp post(client, data, opts) do
    case Tesla.post(client, "/", data, opts) do
      {:ok, %{status: status}} when status < 400 ->
        :ok

      {:ok, %{status: status, body: body}} ->
        _ =
          Logger.warn("HttpSink received error status",
            status: status,
            body: body
          )

        {:error, :http_error_response}

      {:error, reason} ->
        _ = Logger.warn("HttpSink cannot make POST request", reason: reason)
        {:error, :request_failed}
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

  defp build_client(url, opts) do
    headers = Keyword.get(opts, :headers, [])

    middleware = [
      {Tesla.Middleware.BaseUrl, url},
      {Tesla.Middleware.Headers, headers}
    ]

    if Keyword.get(opts, :ignore_ssl_errors) do
      # Build adapter with insecure SSL to ignore SSL errors
      adapter_opts = [insecure: true]
      adapter = {Tesla.Adapter.Hackney, adapter_opts}

      Tesla.client(middleware, adapter)
    else
      # Use default adapter
      Tesla.client(middleware)
    end
  end
end
