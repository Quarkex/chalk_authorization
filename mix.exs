defmodule ChalkAuthorization.MixProject do
  use Mix.Project

  def project do
    [
      app: :chalk_authorization,
      version: "0.1.1",
      description: "Authorization system with role support",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: [
        main: "readme",
        extras: [
          "README.md",
          "cheatsheets/functions.cheatmd",
        ],
        groups_for_extras: [
          Cheatsheets: Path.wildcard("cheatsheets/*.cheatmd")
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.27.0", only: :dev, runtime: false},
    ]
  end

  defp package do
    [
      maintainers: ["Quarkex"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Quarkex/chalk_authorization"}
    ]
  end
end
