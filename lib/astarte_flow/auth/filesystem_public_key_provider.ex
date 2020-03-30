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

defmodule Astarte.Flow.Auth.FilesystemPublicKeyProvider do
  @behaviour Astarte.Flow.Auth.RealmPublicKeyProvider

  require Logger

  alias Astarte.Flow.Config

  @impl true
  @spec fetch_public_key(realm :: String.t()) ::
          {:ok, public_key_pem :: String.t()} | {:error, reason :: term()}
  def fetch_public_key(realm) when is_binary(realm) do
    filename =
      Config.realm_public_keys_dir!()
      |> Path.join(realm <> "-public-key.pem")

    case File.read(filename) do
      {:ok, public_key} ->
        {:ok, public_key}

      {:error, reason} ->
        Logger.warn("Cannot get public key for realm #{realm}: #{inspect(reason)}.",
          tag: "fetch_public_key_error"
        )

        {:error, reason}
    end
  end
end
