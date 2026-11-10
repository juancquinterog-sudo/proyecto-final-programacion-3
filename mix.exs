defmodule Emergencias.MixProject do
  use Mix.Project

  def project do
    [
      app: :emergencias,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # :crypto se usa para guardar las contraseñas como hash (SHA-256).
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Emergencias.Application, []}
    ]
  end

  # El proyecto no usa dependencias externas: solo Elixir/OTP.
  defp deps, do: []
end
