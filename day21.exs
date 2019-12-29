defmodule Day21 do
  @puzzle "day21.puzzle" |> File.read!() |> Cpu.parse_intcodes()

  defp code do
    """
    # if A is hole set T to true
    NOT A T
    # set J to true if A was hole
    OR T J
    # same for B
    NOT B T
    OR T J
    # same for C
    NOT C T
    OR T J
    # Now J is true if there is a hole incoming in either A, B or C
    # We will jump only if we can land on D
    AND D J
    # Now J is true if hole incoming and D is ground.
    # We must ensure that we can also jump from D to H
    #                     or move from D to E.
    # First we set T to false if J is true
    NOT J T
    # Then we will check if H is ground or E is ground 
    # and set T to true in either case
    OR H T
    OR E T
    # If J was false, and T was set to true, T is still true, 
    # meaning that H or E are ground.
    # But still, we will only jump if a hole is comming, requiring 
    # that bot J and T are true, and set J to true if so.
    AND T J
    RUN
    """
  end

  def run() do
    @puzzle
    |> Cpu.run!(
      io: fn
        {:input, []} ->
          exit(:buffer_empty)

        {:input, {[char | inbuf], outbuf}} ->
          IO.write([char])
          {char, {inbuf, outbuf}}

        {:output, damage, {inbuf, outbuf}} when damage > ?z ->
          IO.puts("Ship damage: #{damage}")
          IO.puts("Exit")
          exit(:normal)

        {:output, char, {inbuf, outbuf}} ->
          {inbuf, [char | outbuf]}
      end,
      iostate: {make_buffer(code()), []}
    )
    |> Map.get(:iostate)
    # extract output buffer
    |> elem(1)
    |> :lists.reverse()
    |> List.to_string()
    |> String.split("\n\n")
    |> Enum.map(&add_letters/1)
    |> Enum.intersperse(?\n)
    |> IO.puts()
  end

  defp add_letters(str) do
    str
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "@"))
    |> case do
      [] ->
        str

      list ->
        pos =
          list
          |> hd()
          |> String.graphemes()
          |> Enum.with_index()
          |> Enum.find(fn
            {"@", _} -> true
            _ -> false
          end)
          |> elem(1)

        start = String.duplicate(" ", pos + 1)
        row = start <> "ABCDEFGHI"
        [str, ?\n, row, ?\n]
    end
  end

  def make_buffer(binary) do
    list =
      binary
      |> String.split("\n")
      |> Enum.filter(&filter_comment/1)
      |> Enum.join("\n")
      |> to_charlist

    list ++ [?\n]
  end

  defp filter_comment("#" <> _), do: false
  defp filter_comment(_), do: true
end

Day21.run()
