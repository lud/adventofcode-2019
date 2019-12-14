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

  test "immediate mode" do
    assert Cpu.run!("1002,4,3,4,33") == [1002, 4, 3, 4, 99]
  end

  defp test_day_5(program, expected, inputs) do
    for i <- inputs do
      {:ok, client} = Cpu.boot(program)
      :ok = Cpu.send_input(client, i)
      assert {:ok, output} = Cpu.get_output(client)
      assert expected === output
      assert {:ok, _} = Cpu.await(client)
    end
  end

  test "less_than & equals with immediate and positional" do
    # positional is-equal to 8
    program = "3,9,8,9,10,9,4,9,99,-1,8"
    test_day_5(program, 0, [1, 2, 3, 4, 5, 6, 7, 9, 10, 11])
    test_day_5(program, 1, [8])

    # immediate is-equal to 8
    program = "3,3,1108,-1,8,3,4,3,99"
    test_day_5(program, 0, [1, 2, 3, 4, 5, 6, 7, 9, 10, 11])
    test_day_5(program, 1, [8])

    # positional less-than 8
    program = "3,9,7,9,10,9,4,9,99,-1,8"
    test_day_5(program, 0, [8, 9, 10, 11])
    test_day_5(program, 1, [1, 2, 3, 4, 5, 6, 7])

    # immediate less-than 8
    program = "3,3,1107,-1,8,3,4,3,99"
    test_day_5(program, 0, [8, 9, 10, 11])
    test_day_5(program, 1, [1, 2, 3, 4, 5, 6, 7])

    # compare to 8
    program =
      "3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99"

    test_day_5(program, 999, [1, 2, 3, 4, 5, 6, 7])
    test_day_5(program, 1000, [8])
    test_day_5(program, 1001, [9, 10, 11, 12])
  end
end
