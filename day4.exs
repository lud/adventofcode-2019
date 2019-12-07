defmodule Day4 do
  def run(range_str) do
    [from, to] =
      range_str
      |> String.split("-")
      |> Enum.map(&String.to_integer/1)

    Range.new(from, to)
    |> Stream.map(&to_charlist/1)
    |> Stream.filter(&has_increasing_digits/1)
    |> Enum.filter(&has_dup_digits/1)
    |> length()
  end

  def has_increasing_digits([h, d | _]) when h > d,
    do: false

  def has_increasing_digits([_h, d | t]),
    do: has_increasing_digits([d | t])

  def has_increasing_digits([_]),
    do: true

  def remove([char | list], char),
    do: remove(list, char)

  def remove(list, _),
    do: list

  def has_dup_digits([h, h, h | t]) do
    t
    |> remove(h)
    |> has_dup_digits()
  end

  def has_dup_digits([h, h, _ | _]),
    do: true

  def has_dup_digits([h, h]),
    do: true

  def has_dup_digits([_h, o | t]),
    do: has_dup_digits([o | t])

  def has_dup_digits([_]),
    do: false

  def has_dup_digits([]),
    do: false
end

"254032-789860"
|> Day4.run()
|> IO.inspect(label: "Response: ")

System.halt()
