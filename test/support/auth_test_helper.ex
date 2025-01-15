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

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.

defmodule Astarte.Flow.AuthTestHelper do
  @behaviour Astarte.Flow.Auth.RealmPublicKeyProvider

  alias Astarte.Flow.Auth.Guardian, as: AuthGuardian
  alias Astarte.Flow.Auth.User

  @private_key """
  -----BEGIN EC PRIVATE KEY-----
  MIHcAgEBBEIAfPx/KDPUk71gSYfZbuuUevU355KjPOqKczhEQqJqCdK09kyutlNC
  SNrBLoylsKeuGcoMuEA5gxhXpFOVmnllsfegBwYFK4EEACOhgYkDgYYABAAmEVha
  s6YSCNsJWbXveqtx1JZVXixNgUzATuSRT6UCa7vNTSMZ375/fwmUMyrxlkVKWcoL
  U7vpkHe7Gd2eroADPQAbWjPEfC6CBk4luOZRyHL7VsnB3Faz/QPXaJLHW4CuLIzk
  tl8fRkK1WXeZQpH4jkvxSyd97VDDR+hecknFoxl3PQ==
  -----END EC PRIVATE KEY-----
  """

  @public_key """
  -----BEGIN PUBLIC KEY-----
  MIGbMBAGByqGSM49AgEGBSuBBAAjA4GGAAQAJhFYWrOmEgjbCVm173qrcdSWVV4s
  TYFMwE7kkU+lAmu7zU0jGd++f38JlDMq8ZZFSlnKC1O76ZB3uxndnq6AAz0AG1oz
  xHwuggZOJbjmUchy+1bJwdxWs/0D12iSx1uAriyM5LZfH0ZCtVl3mUKR+I5L8Usn
  fe1Qw0foXnJJxaMZdz0=
  -----END PUBLIC KEY-----
  """

  @impl true
  def fetch_public_key(_realm) do
    {:ok, @public_key}
  end

  def gen_jwt_token(authorization_paths) do
    jwk = JOSE.JWK.from_pem(@private_key)

    {:ok, jwt, _claims} =
      %User{id: "testuser"}
      |> AuthGuardian.encode_and_sign(
        %{a_f: authorization_paths},
        secret: jwk,
        allowed_algos: ["ES512"]
      )

    jwt
  end

  def gen_jwt_all_access_token do
    gen_jwt_token([".*::.*"])
  end
end
