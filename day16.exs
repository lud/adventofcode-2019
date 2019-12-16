defmodule Day16 do
  @pattern [0, 1, 0, -1]

  def compute_signal(input, count) when is_binary(input) do
    input
    |> String.to_integer()
    |> Integer.digits()
    |> compute_signal(count)
  end

  def compute_signal(input, 0) do
    input
    |> Integer.undigits()
  end

  def compute_signal(input, count) do
    phase = compute_phase(input)
    IO.puts("phase #{count}: #{inspect(phase)}")
    compute_signal(phase, count - 1)
  end

  def compute_phase(digits) when is_list(digits) do
    digits
    |> Enum.with_index()
    # |> IO.inspect()
    |> Enum.map(fn {_, index} ->
      compute_digit(digits, index)
    end)
  end

  def compute_digit(digits, index) do
    pattern = repeat_pattern(@pattern, index + 1)

    result =
      digits
      |> Stream.zip(pattern)
      # |> Enum.map(&IO.inspect/1)
      # |> Enum.to_list()
      # |> IO.inspect(label: "zip for #{index + 1}")
      |> Stream.map(fn {digit, mult} ->
        # IO.puts("multiply #{digit} #{mult}")
        digit * mult
      end)
      |> Enum.sum()
      |> Integer.digits()
      |> List.last()
      |> abs()

    # IO.puts("digit computed: #{result}")
    result
  end

  def repeat_pattern(base_pattern, 1) do
    base_pattern
    |> Stream.cycle()
    |> Stream.drop(1)
  end

  def repeat_pattern(base_pattern, duplicates) do
    base_pattern
    # WAY 1
    |> Stream.map(fn n -> [n] |> Stream.cycle() |> Stream.take(duplicates) end)
    |> Stream.flat_map(& &1)
    # WAY 2
    # |> Stream.map(fn n -> List.duplicate(n, duplicates) end)
    # |> Stream.flat_map(& &1)
    # WAY 3
    # |> Stream.map(fn n -> Stream.cycle([n]) end)
    # |> Stream.flat_map(&Stream.take(&1, duplicates))
    # OK
    |> Stream.cycle()
    |> Stream.drop(1)
  end

  def test do
    enum = List.duplicate(1, 100)

    compute_digit([1], 0)
  end
end

# "59772698208671263608240764571860866740121164692713197043172876418614411671204569068438371694198033241854293277505547521082227127768000396875825588514931816469636073669086528579846568167984238468847424310692809356588283194938312247006770713872391449523616600709476337381408155057994717671310487116607321731472193054148383351831456193884046899113727301389297433553956552888308567897333657138353770191097676986516493304731239036959591922009371079393026332649558536888902303554797360691183681625604439250088062481052510016157472847289467410561025668637527408406615316940050060474260802000437356279910335624476330375485351373298491579364732029523664108987"
# "80871224585914546619083218645595"
"12345678"
|> Day16.compute_signal(1)
|> IO.inspect()

# IO.puts("24176176… ?")
# IO.puts("24176176… ?")
IO.puts("48226158 ?")
# IO.puts("68764632…")

System.halt()
