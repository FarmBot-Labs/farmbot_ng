defmodule FarmbotScriptingTest do
  use ExUnit.Case
  doctest FarmbotScripting

  test "greets the world" do
    assert FarmbotScripting.hello() == :world
  end
end
