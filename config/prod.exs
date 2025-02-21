#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
config :astarte_flow, Astarte.FlowWeb.Endpoint,
  url: [host: "example.com", port: 80],
  check_origin: false,
  http: [:inet6, port: String.to_integer(System.get_env("PORT") || "4009")],
  server: true

# Do not print debug messages in production
config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

config :logger, :console,
  format: {PrettyLog.LogfmtFormatter, :format},
  metadata: [
    :method,
    :request_path,
    :status_code,
    :elapsed,
    :realm,
    :module,
    :function,
    :request_id,
    :flow,
    :message,
    :data,
    :status,
    :body,
    :tag
  ]

config :k8s,
  clusters: %{
    default: %{}
  }

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
