defmodule CpuTest do
  use ExUnit.Case
  doctest Cpu

  test "addition, multiplication" do
    assert Cpu.run!("1,0,0,0,99") == [2, 0, 0, 0, 99]

    assert Cpu.run!("2,3,0,3,99") == [2, 3, 0, 6, 99]
    assert Cpu.run!("2,4,4,5,99,0") == [2, 4, 4, 5, 99, 9801]
    assert Cpu.run!("1,1,1,4,99,5,6,0,99") == [30, 1, 1, 4, 2, 5, 6, 0, 99]
  end

  test "IO" do
    assert {:ok, client} = Cpu.boot("3,5,4,5,99")
    assert :ok = Cpu.send_input(client, 1234)
    assert {:ok, 1234} = Cpu.get_output(client)
    assert {:error, {:halted, {:ok, _}}} = Cpu.get_output(client)
  end
end
