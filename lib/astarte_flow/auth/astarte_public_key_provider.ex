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

defmodule Astarte.Flow.Auth.AstartePublicKeyProvider do
  @behaviour Astarte.Flow.Auth.RealmPublicKeyProvider

  require Logger

  alias Astarte.Core.Realm

  @impl true
  @spec fetch_public_key(realm :: String.t()) ::
          {:ok, public_key_pem :: String.t()} | {:error, reason :: term()}
  def fetch_public_key(realm) when is_binary(realm) do
    Xandra.Cluster.run(:xandra, &fetch_realm_public_key(&1, realm))
  end

  defp fetch_realm_public_key(conn, realm_name) do
    statement = """
    SELECT blobAsVarchar(value)
    FROM :realm_name.kv_store
    WHERE group='auth' AND key='jwt_public_key_pem';
    """

    with :ok <- validate_realm_name(realm_name),
         query = String.replace(statement, ":realm_name", realm_name),
         {:ok, %Xandra.Page{} = page} <- Xandra.execute(conn, query, %{}, consistency: :quorum) do
      case Enum.fetch(page, 0) do
        {:ok, %{"system.blobasvarchar(value)" => public_key}} ->
          {:ok, public_key}

        :error ->
          {:error, :public_key_not_found}
      end
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}

      {:error, reason} ->
        _ =
          Logger.warning("Cannot get public key: #{inspect(reason)}.",
            tag: "fetch_public_key_error",
            realm: realm_name
          )

        {:error, reason}
    end
  end

  defp validate_realm_name(realm_name) do
    if Realm.valid_name?(realm_name) do
      :ok
    else
      _ =
        Logger.warning("Invalid realm name.",
          tag: "invalid_realm_name",
          realm: realm_name
        )

      {:error, :realm_not_allowed}
    end
  end
end
