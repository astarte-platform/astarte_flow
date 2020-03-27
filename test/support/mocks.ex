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

Mox.defmock(PairingAgentMock, for: Astarte.API.Pairing.Agent.Behaviour)
Mox.defmock(PairingMock, for: Astarte.API.Pairing.Devices.Behaviour)

Mox.defmock(CredentialsStorageMock,
  for: Astarte.Flow.Blocks.DynamicVirtualDevicePool.CredentialsStorage
)

Mox.defmock(ConnectionMock, for: Astarte.Device.Connection)
Mox.defmock(InterfaceProviderMock, for: Astarte.Device.InterfaceProvider)
Mox.defmock(PipelinesStorageMock, for: Astarte.Flow.Pipelines.Storage)
Mox.defmock(FlowsStorageMock, for: Astarte.Flow.Flows.Storage)
Mox.defmock(PublicKeyProviderMock, for: Astarte.Flow.Auth.RealmPublicKeyProvider)
