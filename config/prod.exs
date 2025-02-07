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

# ## SSL Support
#
# To get SSL working, you will need to add the `https` key
# to the previous section and set your `:url` port to 443:
#
#     config :astarte_flow, AstarteFlowWeb.Endpoint,
#       ...,
#       url: [host: "example.com", port: 443],
#       https: [
#         ...,
#         port: 443,
#         cipher_suite: :strong,
#         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
#         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
#       ]
#
# The `cipher_suite` is set to `:strong` to support only the
# latest and more secure SSL ciphers. This means old browsers
# and clients may not be supported. You can set it to
# `:compatible` for wider support.
#
# `:keyfile` and `:certfile` expect an absolute path to the key
# and cert in disk or a relative path inside priv, for example
# "priv/ssl/server.key". For all supported SSL configuration
# options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
#
# We also recommend setting `force_ssl` in your endpoint, ensuring
# no data is ever sent via http, always redirecting to https:
#
#     config :astarte_flow, AstarteFlowWeb.Endpoint,
#       force_ssl: [hsts: true]
#
# Check `Plug.SSL` for all available options in `force_ssl`.
