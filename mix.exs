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

defmodule Astarte.Flow.MixProject do
  use Mix.Project

  @source_ref "master"
  @source_version String.replace_prefix(@source_ref, "release-", "")
                  |> String.replace("master", "snapshot")

  def project do
    [
      app: :astarte_flow,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      dialyzer_cache_directory: dialyzer_cache_directory(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      homepage_url: "https://docs.astarte-platform.org/flow/#{@source_version}/",
      source_url: "https://github.com/astarte-platform/astarte_flow",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:lager, :logger],
      mod: {Astarte.Flow.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer_cache_directory(:ci) do
    "dialyzer_cache"
  end

  defp dialyzer_cache_directory(_) do
    nil
  end

  defp deps do
    [
      {:astarte_device, github: "astarte-platform/astarte-device-sdk-elixir"},
      {:astarte_core, github: "astarte-platform/astarte_core"},
      {:cors_plug, "~> 2.0"},
      {:cyanide, "~> 1.0"},
      {:certifi, "~> 2.5"},
      {:tortoise, "~> 0.9"},
      {:elixir_uuid, "~> 1.2"},
      {:excoveralls, "~> 0.10", only: :test},
      {:exjsonpath, "~> 0.9.0"},
      {:exjsontemplate, github: "ispirata/exjsontemplate"},
      {:ex_json_schema, "~> 0.7"},
      {:gen_stage, "~> 0.14"},
      {:hackney, "~> 1.15"},
      {:tesla, "~> 1.2"},
      {:dialyzex, github: "Comcast/dialyzex", only: [:dev, :ci]},
      {:mox, "~> 0.5", only: :test},
      {:jason, "~> 1.1"},
      {:k8s, "~> 0.5-rc.1"},
      {:luerl, "~> 0.3"},
      {:prioqueue, "~> 0.2.0"},
      {:modbux, "~> 0.3.9"},
      {:amqp, "~> 2.1"},
      {:phoenix, "~> 1.5.3"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_metrics_prometheus_core, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.11"},
      {:plug_cowboy, "~> 2.2"},
      {:plug_logger_with_meta, "~> 0.1"},
      {:pretty_log, "~> 0.1"},
      {:guardian, "~> 2.0"},
      {:xandra, "~> 0.12"},
      {:skogsra, "~> 2.0"},
      {:castore, "~> 0.1.0"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  # Add here additional documentation files
  defp docs do
    [
      main: "0001-overview",
      extra_section: "Guides",
      assets: "guides/assets",
      logo: "guides/assets/images/mascot.png",
      source_ref: "#{@source_ref}",
      extras: Path.wildcard("guides/*/*.md"),
      groups_for_extras: [
        "Core Concepts": ~r"/core_concepts/",
        "Built-in Blocks": ~r"/blocks/"
      ]
    ]
  end
end
