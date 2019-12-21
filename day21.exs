defmodule Day21 do
  @puzzle "day21.puzzle" |> File.read!() |> Cpu.parse_intcodes()

  @code """
  NOT C J
  AND D J
  NOT A T
  OR T J
  WALK
  """
  def run() do
    @puzzle
    |> Cpu.run(
      io: fn
        {:input, []} ->
          exit(:buffer_empty)

        {:input, [char | buffer]} ->
          IO.write([char])
          {char, buffer}

        {:output, damage, buffer} when damage > ?z ->
          IO.puts("Ship damage: #{damage}")
          buffer

        {:output, char, buffer} ->
          IO.write([char])
          buffer
      end,
      iostate: make_buffer(@code)
    )
  end

  def make_buffer(binary) do
    binary
    |> to_charlist
    |> IO.inspect()
  end
end

Day21.run()
