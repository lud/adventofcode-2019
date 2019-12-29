defmodule Day22Parser do
  def parse_instructions(str, mod) do
    str
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_instruction(&1, mod))
  end

  defp parse_instruction("deck " <> rest, mod) do
    cards_amount = String.to_integer(rest)

    {mod, :deck, [cards_amount]}
  end

  defp parse_instruction("deal with increment " <> rest, mod) do
    {mod, :increment, [String.to_integer(rest)]}
  end

  defp parse_instruction("deal into new stack", mod) do
    {mod, :reverse, []}
  end

  defp parse_instruction("cut " <> rest, mod) do
    {mod, :cut, [String.to_integer(rest)]}
  end

  defp parse_instruction("Result: " <> rest, mod) do
    list =
      rest
      |> String.trim()
      |> String.split(" ")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_integer/1)

    {mod, :check, [list]}
  end
end

defmodule Day22Part1 do
  def run(str, {:track, tracked}) do
    str
    |> Day22Parser.parse_instructions(__MODULE__)
    |> Enum.reduce(nil, fn
      {m, f, a}, acc ->
        IO.puts("run instruction #{inspect({m, f, a}, charlists: :as_lists)}")
        acc = apply(m, f, [acc | a])
        pos = Enum.find_index(acc, fn x -> x == tracked end)
        IO.puts("new position: #{pos}")
        acc
    end)

    # |> Enum.at(2019 )
  end

  def deck(_, cards_amount) do
    IO.puts("create deck of #{inspect(cards_amount)} cards")
    0..(cards_amount - 1) |> Enum.to_list()
  end

  def check(stack, list) do
    if stack == list do
      IO.puts("Checked, ok !")
    else
      IO.puts("Unexpected stack: #{inspect(stack)}")
      IO.puts("Expected: #{inspect(list)}")
    end

    stack
  end

  def increment(stack, inc) do
    # IO.puts("increment: #{inc}")
    new_stack = for _ <- stack, do: nil
    skip = inc - 1

    increment(stack, new_stack, _new_stack_out = [], 0, skip)
  end

  # when all cards are dealed, concat new_stack with new_stack_out
  defp increment([], new_stack, new_stack_out, _, _) do
    :lists.reverse(new_stack_out) ++ new_stack
  end

  # when new_stack is empty, we are at the end of the table, start
  # at the beginning of the table
  defp increment(stack, [], new_stack_out, skipn, skip) do
    new_stack = :lists.reverse(new_stack_out)
    increment(stack, new_stack, [], skipn, skip)
  end

  # when skip is zero, put the top card of the deck instead of the nil
  # on the new_stack_out, and reset skip value
  defp increment([cur | stack], [nil | new_stack], new_stack_out, 0, skip) do
    # IO.puts("Put #{cur} on the table")
    increment(stack, new_stack, [cur | new_stack_out], skip, skip)
  end

  # when skip is zero, put the top card of the deck instead of the nil
  # on the new_stack_out, and reset skip value
  defp increment([cur | stack], [card | new_stack], new_stack_out, 0, skip)
       when is_integer(card) do
    raise "should not have found a card"
  end

  # when skip is not zero, put the nil on the new stack out and decrement skip
  defp increment(stack, [card | new_stack], new_stack_out, skipn, skip) do
    # IO.puts("Skip #{card}")
    increment(stack, new_stack, [card | new_stack_out], skipn - 1, skip)
  end

  def reverse(stack), do: :lists.reverse(stack)

  def cut(stack, n) do
    {cutted, rest} = Enum.split(stack, n)
    rest ++ cutted
  end
end

defmodule Day22Part2 do
  def run(str, state) do
    str
    |> Day22Parser.parse_instructions(__MODULE__)
    |> Enum.reduce(state, fn
      {m, f, a}, %{pos: pos} = state when pos < 0 ->
        IO.warn("#{inspect(state)}")
        raise "bad pos: #{inspect(state)}"

      {m, f, a}, acc ->
        IO.puts("run instruction #{inspect({m, f, a}, charlists: :as_lists)}")
        state = apply(m, f, [acc | a])
        IO.puts("new position: #{state.pos}")
        state
    end)

    # |> Enum.at(2019 )
  end

  def deck({:track, tracked}, cards_amount) do
    # tracked card starts at <itself> position (i.e card zero starts
    # at position 0, and so on)
    state = %{max_index: cards_amount - 1, pos: tracked, track: tracked}
    state
  end

  def reverse(%{max_index: max_index, pos: pos} = state) do
    # if cards a, b, c, d, e, f
    # index of c is 2
    # reverse: f, e, d, c, b, a
    # index of c is 3
    # len is 6
    # max_index is 6 - 1 = 5
    # new_pos = max_index - initial_pos
    # 3 = (6- 1) - 2
    pos = max_index - pos
    %{state | pos: max_index - pos}
  end

  # cut when positive cut
  def cut(%{max_index: max_index, pos: pos} = state, n) when n > 0 do
    # if we cut 3 cards, we cut cards 0,1,2, so the last card to 
    # be cut is 2
    last_cutted_index = n - 1
    # IO.inspect(n, label: :pos)
    # IO.inspect(pos, label: :pos)
    # IO.inspect(last_cutted_index, label: :last_cutted_index)
    # if we are in the cut, pos is augmented by max_index_pos
    # else pos is diminished by it
    pos =
      if pos <= last_cutted_index do
        # in the cut, we are sent backwards by the number of remaining elements
        pos + (max_index - n)
      else
        # not in the cut, we are sent forward by n elements
        # IO.puts("pos = #{pos} - #{n} => #{pos - n}")
        pos - n
      end

    # IO.inspect(pos, label: :new_pos)
    %{state | pos: pos}
  end

  # cut when negative cut, we transform into a positive cut
  def cut(%{max_index: max_index, pos: pos} = state, n) when n < 0 do
    size = max_index + 1
    IO.puts("transform cut of #{n} into #{size + n}")
    # add because n is negative
    cut(state, size + n)
  end

  def increment(%{max_index: max_index, pos: 0} = state, _) do
    # if pos is zero we will not move
    state
  end

  # with an increment of 3, we will have 
  #  - 0 . . 1 at the first turn
  #  - 0 x . 1 at the second turn
  #  - 0 x y 1 and every slot will be filled. So the number of 
  #  turns equals n
  #  We have <size> cards to place, at the first turn we can place
  #  ceil(size/n) cards. if our card was place, it's new pos is pos*n
  #  If not placed, we run another round, but with an offset of 1,
  #  and so on
  def increment(%{max_index: max_index, pos: pos} = state, n) do
    offset = 0
    size = max_index + 1
    pos = increment(size, n, pos, offset)
    %{state | pos: pos}
  end

  def increment(size, n, pos, offset) do
    cards_placed = ceil((size - offset) / n)
    nex_offset = rem(size, cards_placed)
    IO.puts("cards_placed: #{cards_placed}")
    # IO.puts("pos: #{pos}")
    # IO.puts("nex_offset: #{nex_offset}")
    # IO.puts("offset: #{offset}")
    # Process.sleep(100)
    raise "nope, nope, nope"

    if pos < cards_placed do
      pos * n + offset
    else
      size = size
      pos = pos - cards_placed
      increment(size, n, pos, nex_offset)
    end
  end
end

"""
deck 10
deal into new stack
cut -2
deal with increment 7
cut 8
cut -4
deal with increment 7
cut 3
deal with increment 9
deal with increment 3
cut -1
"""

"""
deck 10
cut -4
"""

"day22.puzzle"
|> File.read!()
|> Day22Part2.run({:track, 2019})
|> IO.inspect(charlists: :as_lists)
|> Enum.find_index(fn x -> x == 2019 end)
|> IO.inspect(charlists: :as_lists)

System.halt()
