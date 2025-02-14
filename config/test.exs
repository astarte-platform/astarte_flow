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

config :astarte_device,
  connection_mod: ConnectionMock,
  pairing_devices_mod: PairingMock

config :tesla, adapter: Tesla.Mock

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :astarte_flow, Astarte.FlowWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "X3gHOtNcFe1yn3VG0cJAAiedEkYISl3UNgQanRZG9NCbMZvUnEO1OIGXqqFysOay",
  server: false

config :astarte_flow, :pipelines_storage_mod, PipelinesStorageMock

config :astarte_flow, :flows_storage_mod, FlowsStorageMock

config :astarte_flow, :blocks_storage_mod, BlocksStorageMock

config :astarte_flow, :realm_public_key_provider, PublicKeyProviderMock

config :logger, :console,
  format: {PrettyLog.UserFriendlyFormatter, :format},
  metadata: [
    :method,
    :request_path,
    :status_code,
    :elapsed,
    :realm,
    :module,
    :function,
    :request_id,
    :tag
  ]

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
