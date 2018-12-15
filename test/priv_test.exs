defmodule PrivTest do
  use ExUnit.Case
  doctest Priv

  test "greets the world" do
    assert Priv.hello() == :world
  end
end
