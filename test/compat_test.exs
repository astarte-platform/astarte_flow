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

defmodule Astarte.Flow.CompatTest do
  use ExUnit.Case
  alias Astarte.Flow.Compat

  import ExUnit.CaptureLog

  @warning_pattern "The /v1 suffix is deprecated"

  describe "normalize_device_pairing_url/1" do
    test "returns the same URL for local URL if it doesn't have a trailing `v1`" do
      url = "http://localhost:4003"

      assert Compat.normalize_device_pairing_url(url) == url
    end

    test "returns the same URL for remote URL if it doesn't have a trailing `v1`" do
      url = "https://api.astarte.example.com/pairing/"

      assert Compat.normalize_device_pairing_url(url) == url
    end

    test "returns a normalized URL and prints warning for local URL if it has a trailing `v1`" do
      url = "http://localhost:4003/v1"

      assert capture_log(fn ->
               assert Compat.normalize_device_pairing_url(url) == "http://localhost:4003"
             end) =~ @warning_pattern
    end

    test "returns a normalized URL and prints warning for remote URL if it has a trailing `v1`" do
      url = "https://api.astarte.example.com/pairing/v1/"

      assert capture_log(fn ->
               assert Compat.normalize_device_pairing_url(url) ==
                        "https://api.astarte.example.com/pairing"
             end) =~ @warning_pattern
    end
  end
end
