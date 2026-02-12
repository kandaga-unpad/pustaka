defmodule Voile.MixProject do
  use Mix.Project

  def project do
    [
      app: :voile,
      version: "0.1.0",
      elixir: "~> 1.18",
      license: "Apache-2.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers() ++ [:phoenix_swagger],
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Voile.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:assent, "~> 0.3.1"},
      {:aws, "~> 1.0.10"},
      {:bandit, "~> 1.10"},
      {:barlix, "~> 0.6.0"},
      {:dns_cluster, "~> 0.2.0"},
      {:ecto_sql, "~> 3.13"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:ex_json_schema, "~> 0.11.2"},
      {:finch, "~> 0.21"},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 1.0"},
      {:hackney, "~> 1.20"},
      {:hammer, "~> 7.2"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:html_sanitize_ex, "~> 1.4"},
      {:jason, "~> 1.2"},
      {:lazy_html, ">= 0.1.8", only: :test},
      {:myxql, "~> 0.8"},
      {:nimble_csv, "~> 1.2"},
      {:pbkdf2_elixir, "~> 2.0"},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.7"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:phoenix_live_view, "~> 1.1.22"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_swagger, "~> 0.8"},
      {:phoenix_turnstile, "~> 1.0"},
      {:postgrex, "~> 0.22"},
      {:swoosh, "~> 1.21"},
      {:req, "~> 0.5"},
      {:tailwind, "~> 0.4", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:tzdata, "~> 1.1"},
      {:xml_builder, "~> 2.2"}
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
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": [
        "ecto.create",
        "ecto.migrate",
        "run priv/repo/seeds/seeds.exs",
        "run priv/repo/seeds/metadata_resource_class.exs",
        "run priv/repo/seeds/authorization_seeds_runner.exs",
        "run priv/repo/seeds/metadata_properties.exs",
        "run priv/repo/seeds/master.exs",
        "run priv/repo/seeds/glams.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind voile", "esbuild voile"],
      "assets.deploy": [
        "tailwind voile --minify",
        "esbuild voile --minify",
        "phx.digest"
      ],
      precommit: ["format", "compile"]
    ]
  end
end
