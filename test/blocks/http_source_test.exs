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

defmodule Astarte.Streams.Blocks.HttpSourceTest do
  use ExUnit.Case

  alias Astarte.Streams.Blocks.HttpSource
  alias Astarte.Streams.Message

  @base_url "http://example.com"
  @json_body ~s({"the_answer": 42})
  @xml_body ~s"""
  <?xml version="1.0" encoding="UTF-8"?>
  <note>
    <to>Tove</to>
    <from>Jani</from>
    <heading>Reminder</heading>
    <body>Don't forget me this weekend!</body>
  </note>
  """

  describe "start_link/1" do
    test "fails if base_url is missing" do
      opts = [
        target_paths: ["/test"]
      ]

      assert HttpSource.start_link(opts) == {:error, :missing_base_url}
    end

    test "fails if target_paths is missing" do
      opts = [
        base_url: @base_url
      ]

      assert HttpSource.start_link(opts) == {:error, :missing_target_paths}
    end

    test "fails if target_paths is empty" do
      opts = [
        base_url: @base_url,
        target_paths: []
      ]

      assert HttpSource.start_link(opts) == {:error, :empty_target_paths}
    end

    test "succeeds with correct options" do
      Tesla.Mock.mock(fn
        %{method: :get} ->
          %Tesla.Env{status: 404}
      end)

      opts = [
        base_url: @base_url,
        target_paths: ["/test"],
        polling_interval_ms: 10_000
      ]

      assert {:ok, _pid} = HttpSource.start_link(opts)
    end
  end

  describe "HTTP requests" do
    test "generate messages when successful" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: @base_url <> "/test"} ->
          %Tesla.Env{status: 200, body: "henlo"}
      end)

      opts = [
        base_url: @base_url,
        target_paths: ["/test"]
      ]

      {:ok, pid} = start_supervised({HttpSource, opts})

      [message] =
        GenStage.stream([pid])
        |> Enum.take(1)

      assert %Message{
               key: "/test",
               data: "henlo",
               type: :binary,
               subtype: "application/octet-stream",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url
               }
             } = message
    end

    test "wraps around after exhausting target_paths" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: @base_url <> "/test1"} ->
          %Tesla.Env{status: 200, body: "1"}

        %{method: :get, url: @base_url <> "/test2"} ->
          %Tesla.Env{status: 200, body: "2"}

        %{method: :get, url: @base_url <> "/test3"} ->
          %Tesla.Env{status: 200, body: "3"}
      end)

      opts = [
        base_url: @base_url,
        target_paths: ["/test1", "/test2", "/test3"],
        polling_interval_ms: 50
      ]

      {:ok, pid} = start_supervised({HttpSource, opts})

      [m1, m2, m3, m4] =
        GenStage.stream([pid])
        |> Enum.take(4)

      assert %Message{
               key: "/test1",
               data: "1",
               type: :binary,
               subtype: "application/octet-stream",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url
               }
             } = m1

      assert %Message{
               key: "/test2",
               data: "2",
               type: :binary,
               subtype: "application/octet-stream",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url
               }
             } = m2

      assert %Message{
               key: "/test3",
               data: "3",
               type: :binary,
               subtype: "application/octet-stream",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url
               }
             } = m3

      assert %Message{
               key: "/test1",
               data: "1",
               type: :binary,
               subtype: "application/octet-stream",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url
               }
             } = m4
    end

    test "do not generate messages when status >= 400 is returned" do
      Tesla.Mock.mock_global(fn
        %{method: :get, url: @base_url <> "/test200"} ->
          %Tesla.Env{status: 200, body: "success"}

        %{method: :get, url: @base_url <> "/test404"} ->
          %Tesla.Env{status: 404, body: "error"}
      end)

      opts = [
        base_url: @base_url,
        target_paths: ["/test200", "/test404"],
        polling_interval_ms: 50
      ]

      {:ok, pid} = start_supervised({HttpSource, opts})

      [message1, message2] =
        GenStage.stream([pid])
        |> Enum.take(2)

      assert %Message{
               key: "/test200",
               data: "success",
               type: :binary,
               subtype: "application/octet-stream",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url
               }
             } = message1

      assert %Message{
               key: "/test200",
               data: "success",
               type: :binary,
               subtype: "application/octet-stream",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url
               }
             } = message2
    end

    test "generate metadata and subtype with response headers" do
      base_headers = [
        {"server", "nginx"},
        {"my-custom-header", "my_custom_value"}
      ]

      json_headers = [
        {"content-type", "application/json"}
        | base_headers
      ]

      xml_headers = [
        {"content-type", "application/xml"}
        | base_headers
      ]

      Tesla.Mock.mock_global(fn
        %{method: :get, url: @base_url <> "/test/json"} ->
          %Tesla.Env{
            status: 200,
            body: @json_body,
            headers: json_headers
          }

        %{method: :get, url: @base_url <> "/test/xml"} ->
          %Tesla.Env{
            status: 200,
            body: @xml_body,
            headers: xml_headers
          }
      end)

      opts = [
        base_url: @base_url,
        target_paths: ["/test/json", "/test/xml"],
        polling_interval_ms: 50
      ]

      {:ok, pid} = start_supervised({HttpSource, opts})

      [json_message, xml_message] =
        GenStage.stream([pid])
        |> Enum.take(2)

      assert %Message{
               key: "/test/json",
               data: @json_body,
               type: :binary,
               subtype: "application/json",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url,
                 "Astarte.Streams.Blocks.HttpSource.my-custom-header" => "my_custom_value",
                 "Astarte.Streams.Blocks.HttpSource.server" => "nginx"
               }
             } = json_message

      assert %Message{
               key: "/test/xml",
               data: @xml_body,
               type: :binary,
               subtype: "application/xml",
               metadata: %{
                 "Astarte.Streams.Blocks.HttpSource.base_url" => @base_url,
                 "Astarte.Streams.Blocks.HttpSource.my-custom-header" => "my_custom_value",
                 "Astarte.Streams.Blocks.HttpSource.server" => "nginx"
               }
             } = xml_message
    end
  end
end
