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

import Config

config :astarte_streams,
       :astarte_instance,
       System.get_env("ASTARTE_STREAMS_ASTARTE_INSTANCE", "astarte")

config :astarte_streams,
       :target_namespace,
       System.get_env("ASTARTE_STREAMS_TARGET_NAMESPACE", "astarte")

config :astarte_streams, Astarte.StreamsWeb.Endpoint,
  http: [port: System.get_env("ASTARTE_STREAMS_PORT", "4010") |> String.to_integer()]

config :astarte_streams, :default_amqp_connection,
  host: System.get_env("ASTARTE_STREAMS_DEFAULT_AMQP_CONNECTION_HOST", "localhost"),
  username: System.get_env("ASTARTE_STREAMS_DEFAULT_AMQP_CONNECTION_USERNAME", "guest"),
  password: System.get_env("ASTARTE_STREAMS_DEFAULT_AMQP_CONNECTION_PASSWORD", "guest"),
  virtual_host: System.get_env("ASTARTE_STREAMS_DEFAULT_AMQP_CONNECTION_VIRTUAL_HOST", "/"),
  port:
    System.get_env("ASTARTE_STREAMS_DEFAULT_AMQP_CONNECTION_PORT", "5672") |> String.to_integer()
