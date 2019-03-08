defmodule FluminusCLITest do
  use ExUnit.Case
  doctest FluminusCLI

  test "greets the world" do
    assert FluminusCLI.hello() == :world
  end
end
