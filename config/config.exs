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

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :tesla, adapter: Tesla.Adapter.Hackney

# lager is used by rabbit_common.
# Silent it by setting the higher loglevel.
config :lager,
  error_logger_redirect: false,
  handlers: [level: :critical]

# Configures the endpoint
config :astarte_flow, Astarte.FlowWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "o/WvTw7d0OPFuYFKe9Wk0MtjJsUaiX+g+JkkZIfhg18frniYdbQnZ1DC0V2gZVY4",
  render_errors: [view: Astarte.FlowWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: Astarte.Flow.PubSub

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :astarte_flow, :astarte_instance, "astarte"
config :astarte_flow, :target_namespace, "astarte"

config :astarte_flow, :default_amqp_connection_host, "localhost"
config :astarte_flow, :default_amqp_connection_username, "guest"
config :astarte_flow, :default_amqp_connection_password, "guest"
config :astarte_flow, :default_amqp_connection_virtual_host, "/"
config :astarte_flow, :default_amqp_connection_port, 5672

config :astarte_flow, Astarte.Flow.Auth.Guardian,
  allowed_algos: ["ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "RS256", "RS384", "RS512"]

import_config "#{Mix.env()}.exs"
