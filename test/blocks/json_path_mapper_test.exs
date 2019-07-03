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

defmodule Astarte.Streams.Blocks.JsonPathMapperTest do
  use ExUnit.Case
  alias Astarte.Streams.Blocks.JsonPathMapper
  alias Astarte.Streams.Blocks.JsonPathMapper.Config
  alias Astarte.Streams.Message

  test "simple message from JSON" do
    template = ~S"""
    {
      "type": "real",
      "data": "{{$.data.data[0].values[?(@.name == \"test\")].value}}"
    }
    """

    {:ok, config} = Config.from_keyword(template: template)

    json = ~S"""
    {
      "data" : [
        {
          "timestamp" : "2019-06-20T09:53:25.025Z",
          "values" : [
            {
              "name" : "a",
              "value" : 1.2
            },
            {
              "name" : "test",
              "value" : 2.4
            },
            {
              "name" : "b",
              "value" : 4.8
            }
          ]
        }
      ]
    }
    """

    in_message = %Message{
      data: json,
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: :binary,
      subtype: "application/json"
    }

    out_message = %Message{
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: :real,
      data: 2.4
    }

    assert JsonPathMapper.json_path_transform(in_message, config) == {:ok, out_message}
  end

  test "map message from JSON" do
    template = ~S"""
    {
      "data": {
        "a": "{{$.data.data[0].values[?(@.name == \"a\")].value}}",
        "b": "{{$.data.data[0].values[?(@.name == \"b\")].value}}",
        "c": "{{$.data.data[0].values[?(@.name == \"c\")].value}}"
      },
      "type": {
        "a": "real",
        "b": "real",
        "c": "real"
      }
    }
    """

    {:ok, config} = Config.from_keyword(template: template)

    json = ~S"""
    {
      "data" : [
        {
          "timestamp" : "2019-06-20T09:53:25.025Z",
          "values" : [
            {
              "name" : "a",
              "value" : 1.2
            },
            {
              "name" : "b",
              "value" : 2.4
            },
            {
              "name" : "c",
              "value" : 4.8
            }
          ]
        }
      ]
    }
    """

    in_message = %Message{
      data: json,
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: :binary,
      subtype: "application/json"
    }

    out_message = %Message{
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: %{
        "a" => :real,
        "b" => :real,
        "c" => :real
      },
      data: %{
        "a" => 1.2,
        "b" => 2.4,
        "c" => 4.8
      }
    }

    assert JsonPathMapper.json_path_transform(in_message, config) == {:ok, out_message}
  end

  test "real array message from JSON" do
    template = ~S"""
    {
      "data": "{{$.data.data[0].values[?(@.name != \"b\")].value}}",
      "type": "real_array"
    }
    """

    {:ok, config} = Config.from_keyword(template: template)

    json = ~S"""
    {
      "data" : [
        {
          "timestamp" : "2019-06-20T09:53:25.025Z",
          "values" : [
            {
              "name" : "a",
              "value" : 1.2
            },
            {
              "name" : "b",
              "value" : 2.4
            },
            {
              "name" : "c",
              "value" : 4.8
            }
          ]
        }
      ]
    }
    """

    in_message = %Message{
      data: json,
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: :binary,
      subtype: "application/json"
    }

    out_message = %Message{
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: {:array, :real},
      data: [1.2, 4.8]
    }

    assert JsonPathMapper.json_path_transform(in_message, config) == {:ok, out_message}
  end

  test "real array with just one item message from JSON" do
    template = ~S"""
    {
      "data": "{{$.data.data[0].values[?(@.name != \"b\")].value}}",
      "type": "real_array"
    }
    """

    {:ok, config} = Config.from_keyword(template: template)

    json = ~S"""
    {
      "data" : [
        {
          "timestamp" : "2019-06-20T09:53:25.025Z",
          "values" : [
            {
              "name" : "a",
              "value" : 1.2
            }
          ]
        }
      ]
    }
    """

    in_message = %Message{
      data: json,
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: :binary,
      subtype: "application/json"
    }

    out_message = %Message{
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: {:array, :real},
      data: [1.2]
    }

    assert JsonPathMapper.json_path_transform(in_message, config) == {:ok, out_message}
  end

  test "customize whole message including metadata and key" do
    template = ~S"""
    {
      "key": "{{$.data.data[0].id}}",
      "type": "real",
      "data": "{{$.data.data[0].values[?(@.name == \"test\")].value}}",
      "metadata": {"source_timestamp": "{{$.data.data[0].timestamp}}"}
    }
    """

    {:ok, config} = Config.from_keyword(template: template)

    json = ~S"""
    {
      "data" : [
        {
          "id": "message_id",
          "timestamp" : "2019-06-20T09:53:25.025Z",
          "values" : [
            {
              "name" : "a",
              "value" : 1.2
            },
            {
              "name" : "test",
              "value" : 2.4
            },
            {
              "name" : "b",
              "value" : 4.8
            }
          ]
        }
      ]
    }
    """

    in_message = %Message{
      data: json,
      key: "test",
      timestamp: 1_560_955_493_916_854,
      type: :binary,
      subtype: "application/json"
    }

    out_message = %Message{
      key: "message_id",
      timestamp: 1_560_955_493_916_854,
      type: :real,
      data: 2.4,
      metadata: %{
        "source_timestamp" => "2019-06-20T09:53:25.025Z"
      }
    }

    assert JsonPathMapper.json_path_transform(in_message, config) == {:ok, out_message}
  end
end
