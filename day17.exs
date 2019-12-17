defmodule Day17 do
  @newline 10
  @scaffold ?#
  @robot_up ?^
  @vacuum ?.
  @robot_down ?v
  @robot_left ?<
  @robot_right ?>
  @robot_tumbling ?X
  @robot_scaffold [@robot_up, @robot_down, @robot_left, @robot_right]
  @max_coords {45, 35}
  @start_io_x 10
  defguard is_scaffold(val) when val in @robot_scaffold or val == @scaffold
  defp scaffold?(val) when is_scaffold(val), do: true
  defp scaffold?(val), do: false

  defp build_map(output) do
    build_map(%{}, output, 0, 0)
  end

  defp build_map(map, [@newline | output], _x, y),
    do: build_map(map, output, 0, y + 1)

  defp build_map(map, [robot | output], x, y) when robot in @robot_scaffold do
    map
    |> Map.put({x, y}, @scaffold)
    |> Map.put(:robot, {{x, y}, robot})
    |> build_map(output, x + 1, y)
  end

  defp build_map(map, [@scaffold | output], x, y) do
    map
    |> Map.put({x, y}, @scaffold)
    |> build_map(output, x + 1, y)
  end

  defp build_map(map, [@vacuum | output], x, y) do
    map
    |> build_map(output, x + 1, y)
  end

  defp build_map(map, [], _, _),
    do: map

  defp print_map(map) do
    {{robot_x, robot_y} = robot_xy, robot} = Map.get(map, :robot)
    {max_x, max_y} = @max_coords

    for y <- 0..max_y do
      for x <- 0..max_x do
        char =
          case {x, y} do
            ^robot_xy -> robot
            _ -> Map.get(map, {x, y}, @vacuum)
          end
      end
      |> IO.write()

      IO.write("\n")
    end

    map
  end

  defp move_coords({x, y}, :up), do: {x, y - 1}
  defp move_coords({x, y}, :down), do: {x, y + 1}
  defp move_coords({x, y}, :right), do: {x + 1, y}
  defp move_coords({x, y}, :left), do: {x - 1, y}

  defp cardinal_neighbors({_, _} = coords) do
    [
      move_coords(coords, :up),
      move_coords(coords, :down),
      move_coords(coords, :right),
      move_coords(coords, :left)
    ]
  end

  defp find_intersects(map) do
    map
    |> Enum.filter(fn
      {_, val} when is_scaffold(val) -> true
      _ -> false
    end)
    |> Enum.map(fn {xy, _} -> xy end)
    |> Enum.filter(fn xy ->
      xy
      |> cardinal_neighbors()
      |> Enum.all?(fn n_xy -> scaffold?(Map.get(map, n_xy)) end)
    end)
  end

  defp alignment_param({x, y}), do: x * y

  def run(puzzle) do
    output =
      puzzle
      |> Cpu.run!(io: fn {:output, value, state} -> [value | state] end, iostate: [])
      |> Map.get(:iostate)
      |> :lists.reverse()

    # output =
    #   """
    #   ..#..........
    #   ..#..........
    #   #######...###
    #   #.#...#...#.#
    #   #############
    #   ..#...#...#..
    #   ..#####...^..
    #   """
    #   |> String.to_charlist()

    IO.puts(output)

    map = build_map(output)

    intersects =
      find_intersects(map)
      |> IO.inspect()

    intersects
    |> Enum.reduce(map, fn xy, map -> Map.put(map, xy, ?O) end)
    |> print_map()

    intersects
    |> Enum.map(&alignment_param/1)
    |> Enum.sum()
    |> IO.inspect(label: "Aligment sum")

    # mov_A = "L,4,L,4,L,6\n"
    # mov_B = "R,10,L,6\n"
    # mov_C = "L,12,L,6,R,10\n"
    # mov_routine = "A,B,A,B,C,A\n"

    mov_A = "L,4,L,4,L,6,R,10,L,6\n"
    mov_B = "L,12,L,6,R,10,L,6\n"
    mov_C = "R,8,R,10,L,6\n"
    # mov_routine = "A,B,A,B,C\n"
    mov_routine = "A,A,B,C,C,A,C,B,C,B\n"

    paths = [mov_routine, mov_A, mov_B, mov_C] |> Enum.map(&to_charlist/1) |> Enum.concat()
    state = %{paths: paths, out: [], prev_out: output, feed: [?y]}
    IO.write("\n")
    IO.write([IO.ANSI.clear()])

    puzzle
    |> Cpu.run!(
      transform: fn [1 | rest] -> [2 | rest] end,
      io: fn
        {:input, %{paths: [char | chars]} = state} ->
          {char, %{state | paths: chars}}

        {:input, %{paths: [], feed: [yesno]} = state} ->
          {yesno, %{state | feed: []}}

        {:input, %{paths: [], feed: []}} ->
          {?\n, state}

        {:output, v, state} when v > ?z ->
          IO.write([IO.ANSI.cursor(50, 0), "final output: #{v}\n"])
          state

        {:output, 10, state} ->
          state =
            case Process.put(:previous, 10) do
              10 ->
                %{out: out} = state

                out = :lists.reverse(out)

                prev_out =
                  if length(out) != 0 do
                    print_out(out, state.prev_out, y = 2, x = @start_io_x)
                    # Process.sleep(100)
                    out
                  else
                    state.prev_out
                  end

                %{state | out: [], prev_out: prev_out}

              _ ->
                %{out: out} = state

                %{state | out: [10 | out]}
            end

          IO.write([10])
          state

        {:output, val, state} ->
          %{out: out} = state
          Process.put(:previous, val)
          %{state | out: [val | out]}
      end,
      iostate: state
    )
  end

  defp print_out(out, _, y, x) do
    IO.write([IO.ANSI.cursor(0, 0), out])
    IO.write([IO.ANSI.cursor(0, 0), IO.ANSI.reset()])
  end

  # defp print_out([10 | out], [10 | prev], y, x),
  #   do: print_out(out, prev, y + 1, @start_io_x)

  # defp print_out([diff | out], [old | prev], y, x) do
  #   IO.write([IO.ANSI.cursor(y, x), diff])
  #   print_out(out, prev, y, x + 1)
  # end

  # defp print_out([same | out], [same | prev], y, x) do
  #   print_out(out, prev, y, x + 1)
  # end

  # defp print_out([], _, _, _) do
  #   IO.write([IO.ANSI.cursor(50, 2), IO.ANSI.reset()])
  # end
end

puzzle =
  "day17.puzzle"
  |> File.read!()

puzzle
|> Day17.run()

System.halt()
