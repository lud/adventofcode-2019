defmodule Day19 do
  def part1(input) do
    machine = Intcode.new(input)

    for col <- 0..49, row <- 0..49 do
      case in_beam?(col, row, machine) do
        true -> [1]
        false -> []
      end
    end
    |> List.flatten()
    |> Enum.sum()
  end

  def part2(input, size) do
    machine = Intcode.new(input)

    rows(machine)
    |> Enum.find_value(fn pos -> fits?(pos, size, machine) end)
  end

  defp fits?({first, row}, size, machine) do
    ur_fits?(first, row, size, machine) and
      really_fits?(first, row, size, machine)
  end

  defp really_fits?(col, row, size, machine) do
    case ur_fits?(col, row, size, machine) do
      false ->
        false

      true ->
        case ll_fits?(col, row, size, machine) do
          true ->
            case lr_fits?(col, row, size, machine) do
              true ->
                10_000 * col + row

              false ->
                false
            end

          false ->
            really_fits?(col + 1, row, size, machine)
        end
    end
  end

  defp ur_fits?(first, row, size, machine) do
    in_beam?(first + size - 1, row, machine)
  end

  defp ll_fits?(first, row, size, machine) do
    in_beam?(first, row + size - 1, machine)
  end

  defp lr_fits?(first, row, size, machine) do
    in_beam?(first + size - 1, row + size - 1, machine)
  end

  defp rows(machine) do
    Stream.iterate({0, 10}, &get_row(&1, machine))
  end

  defp get_row({col, row}, machine) do
    row = row + 1

    first =
      Enum.find(col..(col + 100), fn col ->
        in_beam?(col, row, machine)
      end)

    {first, row}
  end

  defp in_beam?(col, row, machine) do
    machine = Intcode.set_input(machine, [col, row])
    machine = Intcode.execute(machine)
    {[output], _machine} = Intcode.get_output(machine)
    output === 1
  end
end

defmodule Intcode do
  def new(program) do
    machine(program)
  end

  defp machine(input) do
    memory = read_program(input)
    memory = Map.put(memory, :ip, 0)
    Map.put(memory, :output, :queue.new())
  end

  def set_input(memory, input) do
    Map.put(memory, :input, input)
  end

  def get_output(memory) do
    q = Map.fetch!(memory, :output)
    Map.put(memory, :output, :queue.new())
    {:queue.to_list(q), memory}
  end

  def resume(memory) do
    execute(memory, Map.fetch!(memory, :ip))
  end

  def execute(memory, ip \\ 0) do
    {opcode, modes} = fetch_opcode(memory, ip)

    case opcode do
      1 ->
        memory = exec_arith_op(&+/2, modes, memory, ip)
        execute(memory, ip + 4)

      2 ->
        memory = exec_arith_op(&*/2, modes, memory, ip)
        execute(memory, ip + 4)

      3 ->
        case exec_input(modes, memory, ip) do
          {:suspended, memory} ->
            memory

          memory ->
            execute(memory, ip + 2)
        end

      4 ->
        memory = exec_output(modes, memory, ip)
        execute(memory, ip + 2)

      5 ->
        ip = exec_if(&(&1 !== 0), modes, memory, ip)
        execute(memory, ip)

      6 ->
        ip = exec_if(&(&1 === 0), modes, memory, ip)
        execute(memory, ip)

      7 ->
        memory = exec_cond(&(&1 < &2), modes, memory, ip)
        execute(memory, ip + 4)

      8 ->
        memory = exec_cond(&(&1 === &2), modes, memory, ip)
        execute(memory, ip + 4)

      9 ->
        memory = exec_inc_rel_base(modes, memory, ip)
        execute(memory, ip + 2)

      99 ->
        memory
    end
  end

  defp exec_arith_op(op, modes, memory, ip) do
    [in1, in2] = read_operand_values(memory, ip + 1, modes, 2)
    out_addr = read_out_address(memory, div(modes, 100), ip + 3)
    result = op.(in1, in2)
    write(memory, out_addr, result)
  end

  defp exec_input(modes, memory, ip) do
    out_addr = read_out_address(memory, modes, ip + 1)

    case Map.get(memory, :input, []) do
      [] ->
        {:suspended, Map.put(memory, :ip, ip)}

      [value | input] ->
        memory = write(memory, out_addr, value)
        Map.put(memory, :input, input)
    end
  end

  defp exec_output(modes, memory, ip) do
    [value] = read_operand_values(memory, ip + 1, modes, 1)
    q = Map.fetch!(memory, :output)
    q = :queue.in(value, q)
    Map.put(memory, :output, q)
  end

  defp exec_if(op, modes, memory, ip) do
    [value, new_ip] = read_operand_values(memory, ip + 1, modes, 2)

    case op.(value) do
      true -> new_ip
      false -> ip + 3
    end
  end

  defp exec_cond(op, modes, memory, ip) do
    [operand1, operand2] = read_operand_values(memory, ip + 1, modes, 2)
    out_addr = read_out_address(memory, div(modes, 100), ip + 3)

    result =
      case op.(operand1, operand2) do
        true -> 1
        false -> 0
      end

    write(memory, out_addr, result)
  end

  defp exec_inc_rel_base(modes, memory, ip) do
    [offset] = read_operand_values(memory, ip + 1, modes, 1)
    base = get_rel_base(memory) + offset
    Map.put(memory, :rel_base, base)
  end

  defp read_operand_values(_memory, _addr, _modes, 0), do: []

  defp read_operand_values(memory, addr, modes, n) do
    operand = read(memory, addr)

    operand =
      case rem(modes, 10) do
        0 -> read(memory, operand)
        1 -> operand
        2 -> read(memory, operand + get_rel_base(memory))
      end

    [operand | read_operand_values(memory, addr + 1, div(modes, 10), n - 1)]
  end

  defp read_out_address(memory, modes, addr) do
    out_addr = read(memory, addr)

    case modes do
      0 -> out_addr
      2 -> get_rel_base(memory) + out_addr
    end
  end

  defp fetch_opcode(memory, ip) do
    opcode = read(memory, ip)
    modes = div(opcode, 100)
    opcode = rem(opcode, 100)
    {opcode, modes}
  end

  defp get_rel_base(memory) do
    Map.get(memory, :rel_base, 0)
  end

  defp read(memory, addr) do
    Map.get(memory, addr, 0)
  end

  defp write(memory, addr, value) do
    Map.put(memory, addr, value)
  end

  defp read_program(input) do
    String.split(input, ",")
    |> Stream.map(&String.to_integer/1)
    |> Stream.with_index()
    |> Stream.map(fn {code, index} -> {index, code} end)
    |> Map.new()
  end
end

Day19.part2(
  "109,424,203,1,21102,1,11,0,1106,0,282,21101,0,18,0,1105,1,259,1201,1,0,221,203,1,21102,31,1,0,1105,1,282,21101,38,0,0,1106,0,259,20101,0,23,2,22102,1,1,3,21101,0,1,1,21101,0,57,0,1106,0,303,2101,0,1,222,21001,221,0,3,20102,1,221,2,21102,1,259,1,21102,1,80,0,1106,0,225,21101,33,0,2,21102,1,91,0,1106,0,303,1201,1,0,223,21002,222,1,4,21101,259,0,3,21101,0,225,2,21101,225,0,1,21101,0,118,0,1106,0,225,20101,0,222,3,21102,1,102,2,21102,133,1,0,1105,1,303,21202,1,-1,1,22001,223,1,1,21101,148,0,0,1106,0,259,2101,0,1,223,21001,221,0,4,21002,222,1,3,21101,0,15,2,1001,132,-2,224,1002,224,2,224,1001,224,3,224,1002,132,-1,132,1,224,132,224,21001,224,1,1,21102,195,1,0,106,0,108,20207,1,223,2,21001,23,0,1,21102,1,-1,3,21101,0,214,0,1105,1,303,22101,1,1,1,204,1,99,0,0,0,0,109,5,2102,1,-4,249,22101,0,-3,1,22101,0,-2,2,21202,-1,1,3,21101,250,0,0,1105,1,225,22102,1,1,-4,109,-5,2106,0,0,109,3,22107,0,-2,-1,21202,-1,2,-1,21201,-1,-1,-1,22202,-1,-2,-2,109,-3,2105,1,0,109,3,21207,-2,0,-1,1206,-1,294,104,0,99,22101,0,-2,-2,109,-3,2106,0,0,109,5,22207,-3,-4,-1,1206,-1,346,22201,-4,-3,-4,21202,-3,-1,-1,22201,-4,-1,2,21202,2,-1,-1,22201,-4,-1,1,22101,0,-2,3,21102,1,343,0,1106,0,303,1106,0,415,22207,-2,-3,-1,1206,-1,387,22201,-3,-2,-3,21202,-2,-1,-1,22201,-3,-1,3,21202,3,-1,-1,22201,-3,-1,2,22102,1,-4,1,21102,384,1,0,1106,0,303,1106,0,415,21202,-4,-1,-4,22201,-4,-3,-4,22202,-3,-2,-2,22202,-2,-4,-4,22202,-3,-2,-3,21202,-4,-1,-2,22201,-3,-2,1,21202,1,1,-4,109,-5,2106,0,0",
  100
)
|> IO.inspect()
