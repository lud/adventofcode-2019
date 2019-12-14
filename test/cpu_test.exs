defmodule CpuTest do
  use ExUnit.Case
  doctest Cpu

  test "run simple things" do
    assert Cpu.run!("1,0,0,0,99") == [2, 0, 0, 0, 99]
  end
end
