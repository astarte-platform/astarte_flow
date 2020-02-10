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

defmodule Astarte.Flow.Blocks.JsonPathMapper.JsonTemplateTest do
  use ExUnit.Case
  alias Astarte.Flow.Blocks.JsonPathMapper.JsonTemplate

  test "render string literal" do
    assert JsonTemplate.compile_template("foo bar") == {:ok, "foo bar"}
  end

  test "render number literal" do
    assert JsonTemplate.compile_template(42) == {:ok, 42}
  end

  test "render string interpolation using a map" do
    {:ok, compiled_template} = JsonTemplate.compile_template("Hello {{ $.first_name }}!")

    map = %{"first_name" => "Foo", "last_name" => "Bar"}
    assert JsonTemplate.render(compiled_template, map) == {:ok, "Hello Foo!"}
  end

  test "render string interpolation which begins with {{ using a map" do
    {:ok, compiled_template} = JsonTemplate.compile_template("{{ $.first_name }} ")

    map = %{"first_name" => "Foo", "last_name" => "Bar"}
    assert JsonTemplate.render(compiled_template, map) == {:ok, "Foo "}
  end

  test "render multiple string interpolation using a map" do
    template = "x: {{ $.x }}, y: {{ $.y }}, z: 0"
    {:ok, compiled_template} = JsonTemplate.compile_template(template)

    map = %{"x" => 0.5, "y" => -1.0, "t" => 5.3}
    expected_rendered = "x: 0.5, y: -1.0, z: 0"
    assert JsonTemplate.render(compiled_template, map) == {:ok, expected_rendered}
  end

  test "render placeholder using a map" do
    {:ok, compiled_template} = JsonTemplate.compile_template("{{ $.data }}")

    map = %{"data" => %{"1" => 1, "a" => "A"}}
    assert JsonTemplate.render(compiled_template, map) == {:ok, %{"1" => 1, "a" => "A"}}
  end

  test "render map with placeholder using a map" do
    template = %{"data" => %{"result" => "{{ $.data }}"}}
    {:ok, compiled_template} = JsonTemplate.compile_template(template)

    map = %{"data" => %{"1" => 1, "a" => "A"}}
    expected_rendered = %{"data" => %{"result" => %{"1" => 1, "a" => "A"}}}
    assert JsonTemplate.render(compiled_template, map) == {:ok, expected_rendered}
  end

  test "render array with placeholders using a map" do
    template = ["{{ $.data.x }}", "{{ $.data.y }}", 0]
    {:ok, compiled_template} = JsonTemplate.compile_template(template)

    map = %{"data" => %{"x" => 0.5, "y" => -1.0, "t" => 5.3}}
    expected_rendered = [0.5, -1.0, 0]
    assert JsonTemplate.render(compiled_template, map) == {:ok, expected_rendered}
  end

  test "render array with string interpolation using a map" do
    template = %{"data" => ["x: {{ $.x }}", "y: {{ $.y }}", "z: 0"]}
    {:ok, compiled_template} = JsonTemplate.compile_template(template)

    map = %{"x" => 0.5, "y" => -1.0, "t" => 5.3}
    expected_rendered = %{"data" => ["x: 0.5", "y: -1.0", "z: 0"]}
    assert JsonTemplate.render(compiled_template, map) == {:ok, expected_rendered}
  end
end
