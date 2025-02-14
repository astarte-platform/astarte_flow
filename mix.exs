#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
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
      {:astarte_device, github: "astarte-platform/astarte-device-sdk-elixir", tag: "v1.1.1"},
      {:astarte_core, github: "astarte-platform/astarte_core", tag: "v1.2.0", override: "true"},
      {:cors_plug, "~> 2.0.3"},
      {:cyanide, "~> 2.0"},
      {:certifi, "~> 2.12"},
      {:tortoise, "~> 0.10.0"},
      {:elixir_uuid, "~> 1.2.1"},
      {:excoveralls, "~> 0.16.1", only: :test},
      {:exjsontemplate, github: "secomind/exjsontemplate"},
      {:ex_json_schema, "~> 0.10.2"},
      {:gen_stage, "~> 1.2.1"},
      {:hackney, "~> 1.20.1"},
      {:tesla, "~> 1.12.3"},
      {:dialyzex, github: "Comcast/dialyzex", only: [:dev, :ci]},
      {:mox, "~> 0.5.2", only: :test},
      {:jason, "~> 1.4.4"},
      {:k8s, "~> 0.5.2"},
      {:luerl, "~> 0.4"},
      {:prioqueue, "~> 0.2.7"},
      {:modbux, "~> 0.3.13"},
      {:amqp, "~> 2.1.2"},
      {:phoenix, "~> 1.7.18"},
      {:phoenix_pubsub, "~> 2.1.3"},
      {:phoenix_ecto, "~> 4.6.3"},
      {:telemetry_metrics, "~> 1.1.0"},
      {:telemetry_metrics_prometheus_core, "~> 1.2.1"},
      {:telemetry_poller, "~> 0.5.1"},
      {:gettext, "~> 0.26.2"},
      {:bandit, "~> 1.5"},
      {:dns_cluster, "~> 0.1.1"},
      {:plug_logger_with_meta, "~> 0.1"},
      {:pretty_log, "~> 0.9.0"},
      {:guardian, "~> 2.3.2"},
      {:xandra, "~> 0.19.2"},
      {:skogsra, "~> 2.5.0"},
      {:castore, "~> 0.1.22"},
      {:ex_doc, "~> 0.36.1", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"]
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
