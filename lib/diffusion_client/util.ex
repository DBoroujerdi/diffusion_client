defmodule Diffusion.Util do

  def split(string) do
    case :binary.split(string, "!") do
      [left, right] ->
        [left, "!" <> right]
      _ ->
        :error
    end
  end
end
