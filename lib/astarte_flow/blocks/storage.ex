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

defmodule Astarte.Flow.Blocks.Storage do
  @callback list_blocks(realm :: String.t()) :: [Astarte.Flow.Blocks.Block.t()]

  @callback fetch_block(realm :: String.t(), name :: String.t()) ::
              {:ok, Astarte.Flow.Blocks.Block.t()} | {:error, reason :: term()}

  @callback insert_block(realm :: String.t(), pipeline :: Astarte.Flow.Blocks.Block.t()) ::
              :ok | {:error, reason :: term()}

  @callback delete_block(realm :: String.t(), name :: String.t()) ::
              :ok | {:error, reason :: term()}
end
