defmodule Day1 do
  def fuel(n) when is_integer(n) do
    div(n, 3) - 2
  end

  def run_file(path) do
    path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> run_list()
  end

  def run_str(str) do
    str
    |> String.split("\n")
    |> run_list()
  end

  def run_list(modules) do
    modules
    |> Stream.map(&String.to_integer/1)
    |> Stream.map(&run_module/1)
    |> Enum.reduce(&(&1 + &2))
    |> IO.inspect(label: "Total modules fuel")
  end

  def run_module(int) do
    int
    |> fuel()
    |> IO.inspect(label: "Module Fuel")
    |> fuel_for_fuel()
    |> IO.inspect(label: "Total Fuel")
  end

  def fuel_for_fuel(modules_fuel) do
    modules_fuel + fuel_for_fuel2(modules_fuel)
  end

  def fuel_for_fuel2(current) do
    more_fuel = fuel(current)
    IO.puts("more: #{more_fuel}")

    case more_fuel do
      added when added > 0 ->
        IO.puts("continue")
        added + fuel_for_fuel2(added)

      _none ->
        IO.puts("stop")
        0
    end
  end
end

# Day1.run_str("1969\n100756")
Day1.run_file("day1.txt")
System.halt()
