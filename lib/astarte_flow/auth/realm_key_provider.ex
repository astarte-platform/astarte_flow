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

defmodule Astarte.Flow.Auth.RealmPublicKeyProvider do
  use Skogsra.Type

  alias Astarte.Flow.Auth.AstartePublicKeyProvider
  alias Astarte.Flow.Auth.FilesystemPublicKeyProvider

  @callback fetch_public_key(realm :: String.t()) ::
              {:ok, public_key_pem :: String.t()} | {:error, reason :: term()}

  @impl Skogsra.Type
  @spec cast(String.t()) :: {:ok, module()} | :error
  def cast(value)

  def cast(provider) when is_atom(provider) do
    if function_exported?(provider, :fetch_public_key, 1) do
      {:ok, provider}
    else
      :error
    end
  end

  def cast("astarte") do
    {:ok, AstartePublicKeyProvider}
  end

  def cast("filesystem") do
    {:ok, FilesystemPublicKeyProvider}
  end

  def cast(_provider) do
    :error
  end
end
