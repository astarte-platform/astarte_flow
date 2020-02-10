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

defmodule Astarte.Flow.Blocks.JsonPathMapper.JsonTemplate do
  @moduledoc """
  Implements a simple logic less templating system that allows to write map templates with a syntax
  that resembles mustache syntax, that can be used for JSON templating.
  """

  @type template_base_type() :: String.t() | number() | boolean() | nil
  @type template() ::
          template_base_type() | list(template()) | %{optional(String.t()) => template()}

  @opaque compiled_item() :: template_base_type() | {atom(), any()}
  @opaque compiled_template() ::
            compiled_item()
            | list(compiled_template())
            | %{optional(compiled_template()) => compiled_template()}

  @type rendered_template() ::
          template_base_type()
          | list(rendered_template())
          | %{optional(String.t()) => rendered_template()}

  @spec compile_template(template()) :: {:ok, compiled_template()} | {:error, any()}
  def compile_template(template_list)

  def compile_template(template_list) when is_list(template_list) do
    result =
      Enum.reduce_while(template_list, {:ok, []}, fn value, {:ok, acc} ->
        with {:ok, compiled_value} <- compile_template(value) do
          {:cont, {:ok, [compiled_value | acc]}}
        else
          error -> {:halt, error}
        end
      end)

    with {:ok, compiled_list} <- result do
      {:ok, Enum.reverse(compiled_list)}
    end
  end

  def compile_template(template_map) when is_map(template_map) do
    Enum.reduce_while(template_map, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, compiled_key} <- compile_template(key),
           {:ok, compiled_value} <- compile_template(value) do
        {:cont, {:ok, Map.put(acc, compiled_key, compiled_value)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  def compile_template("{{" <> rest = item) when is_binary(item) do
    if String.slice(rest, -2, 2) == "}}" do
      path_string = String.slice(rest, 0..-3)

      with {:ok, json_path} <- ExJsonPath.compile(path_string) do
        {:ok, {:json_path, json_path}}
      end
    else
      make_string_interpolation(item)
    end
  end

  def compile_template(item) when is_binary(item) do
    if String.contains?(item, "{{") do
      make_string_interpolation(item)
    else
      {:ok, item}
    end
  end

  def compile_template(item) do
    {:ok, item}
  end

  defp make_string_interpolation(string) do
    {:ok, {:reverse_concat, make_string_interpolation(string, [])}}
  end

  defp make_string_interpolation(s, acc) do
    case String.split(s, ["{{", "}}"], parts: 3) do
      [literal_string, expr, rest] ->
        new_acc = [{:json_path, expr}, literal_string | acc]
        make_string_interpolation(rest, new_acc)

      [literal_string, expr, ""] ->
        [{:json_path, expr}, literal_string | acc]

      [literal_string] ->
        [literal_string | acc]
    end
  end

  @spec render(compiled_template(), any()) :: {:ok, rendered_template()} | {:error, any()}
  def render(template, input)

  def render(template, input) when is_map(template) do
    Enum.reduce_while(template, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, rendered_key} <- render(key, input),
           {:ok, rendered_value} <- render(value, input) do
        {:cont, {:ok, Map.put(acc, rendered_key, rendered_value)}}
      else
        error ->
          {:halt, error}
      end
    end)
  end

  def render(template, input) when is_list(template) do
    result =
      Enum.reduce_while(template, {:ok, []}, fn value, {:ok, acc} ->
        with {:ok, rendered_value} <- render(value, input) do
          {:cont, {:ok, [rendered_value | acc]}}
        else
          error ->
            {:halt, error}
        end
      end)

    with {:ok, reversed_list} <- result do
      {:ok, Enum.reverse(reversed_list)}
    end
  end

  def render({:reverse_concat, tokens}, input) do
    result =
      Enum.reduce_while(tokens, {:ok, []}, fn value, {:ok, acc} ->
        with {:ok, rendered_value} <- render(value, input),
             {:map, false} <- {:map, is_map(rendered_value)},
             {:list, false} <- {:list, is_list(rendered_value)} do
          {:cont, {:ok, [rendered_value | acc]}}
        else
          {:map, true} ->
            {:error, :cannot_render_template}

          {:list, true} ->
            {:error, :cannot_render_template}

          error ->
            {:halt, error}
        end
      end)

    with {:ok, string_tokens} <- result do
      {:ok, Enum.join(string_tokens, "")}
    end
  end

  def render({:json_path, path}, input) do
    case ExJsonPath.eval(input, path) do
      [result] -> {:ok, result}
      result when not is_tuple(result) -> {:ok, result}
      _any -> {:error, :cannot_render_template}
    end
  end

  def render(literal_value, _input) do
    {:ok, literal_value}
  end
end
