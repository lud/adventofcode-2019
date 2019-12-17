defmodule Day17 do
  def iostate() do
    []
  end

  def io({:output, value, state}) do
    [value | state]
  end

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
      |> Cpu.run!(io: &Day17.io/1, iostate: Day17.iostate())
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
  end
end

puzzle =
  "day17.puzzle"
  |> File.read!()

puzzle
|> Day17.run()

System.halt()
