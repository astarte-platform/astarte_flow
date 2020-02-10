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

defmodule Astarte.Flow.Blocks.MqttSource.Handler do
  @moduledoc false

  use Tortoise.Handler

  require Logger
  alias Astarte.Flow.Message

  @broker_url_meta_key "Astarte.Flow.Blocks.MqttSource.broker_url"

  @impl true
  def init(opts) do
    source_pid = Keyword.fetch!(opts, :source_pid)
    broker_url = Keyword.fetch!(opts, :broker_url)
    subtype = Keyword.fetch!(opts, :subtype)

    state = %{
      source_pid: source_pid,
      broker_url: broker_url,
      subtype: subtype
    }

    {:ok, state}
  end

  def connection(:up, state) do
    _ = Logger.info("Connected")
    {:ok, state}
  end

  def connection(:down, state) do
    _ = Logger.info("Disconnected")
    {:ok, state}
  end

  @impl true
  def handle_message(topic_tokens, payload, state) do
    %{
      source_pid: source_pid,
      broker_url: broker_url,
      subtype: subtype
    } = state

    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    key = Path.join(topic_tokens)

    message = %Message{
      key: key,
      data: payload,
      type: :binary,
      subtype: subtype,
      metadata: %{@broker_url_meta_key => broker_url},
      timestamp: timestamp
    }

    GenStage.cast(source_pid, {:new_message, message})

    {:ok, state}
  end
end
