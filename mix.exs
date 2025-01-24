defmodule LiveBulkAsync.MixProject do
  @moduledoc false

  use Mix.Project

  @app :live_bulk_async
  @name "LiveBulkAsync"
  @description "LiveBulkAsync is a small library that extends LiveView's async support to work with LiveComponent's `update_many` function"
  @version "0.1.0"
  @github "https://github.com/sezaru/#{@app}"
  @author "Eduardo Barreto Alexandre"
  @license "MIT"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.18",
      name: @name,
      description: @description,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @github,
      extras: [
        "README.md"
      ]
    ]
  end

  defp package do
    [
      name: @app,
      maintainers: [@author],
      licenses: [@license],
      links: %{"Github" => @github},
      files: ~w(lib README.md LICENSE mix.exs)
    ]
  end
end
