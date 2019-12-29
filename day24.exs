defmodule Day24 do
  @bug ?#
  @empty ?.
  def part1(str) do
    str
    |> GridMap.parse_map()
    |> find_repeat_layout()
  end

  defp find_repeat_layout(map),
    do: find_repeat_layout(map, %{map => 1})

  defp find_repeat_layout(map, seen) do
    nmap = next(map)

    if Map.has_key?(seen, nmap) do
      IO.puts("Found state")

      nmap
      |> GridMap.print_map(fn
        _, nil -> "?"
        _, x -> x
      end)
      |> bio_rate
    else
      find_repeat_layout(nmap, Map.put(seen, nmap, 1))
    end
  end

  defp map_to_list(map) do
    map
    |> GridMap.render_map()
    |> :lists.flatten()
  end

  defp bio_rate(map) do
    map
    |> map_to_list
    |> Enum.with_index()
    |> Enum.reduce(0, fn
      {@bug, idx}, acc ->
        IO.puts("Tile #{idx + 1} is worth #{trunc(:math.pow(2, idx))}")
        acc + trunc(:math.pow(2, idx))

      _, acc ->
        acc
    end)
  end

  defp next(map) do
    GridMap.fmap(map, fn coords, content ->
      # A bug dies (becoming an empty space) unless there is exactly
      # one bug adjacent to it.
      # An empty space becomes infested with a bug if exactly one or
      # two bugs are adjacent to it.
      evolve(content, count_adjacent_bugs(coords, map))
    end)
  end

  defp evolve(content, adjacent_bugs) do
    case {content, adjacent_bugs} do
      {@bug, 1} -> @bug
      {@bug, _} -> @empty
      {@empty, 1} -> @bug
      {@empty, 2} -> @bug
      {@empty, _} -> @empty
    end
  end

  defp count_adjacent_bugs(coords, map) do
    coords
    |> GridMap.cardinal_neighbours()
    |> Enum.reduce(0, fn coords, acc ->
      case Map.get(map, coords, @empty) do
        @empty -> acc
        @bug -> acc + 1
      end
    end)
  end

  def part2(str) do
    maps = %{0 => GridMap.parse_map(str)}
    run_3d(maps, 0..0, 200)
  end

  defp run_3d(maps, _keyrange, 0) do
    maps
    |> Enum.each(fn {level, map} ->
      IO.puts("Depth #{level}:")
      GridMap.print_map(map)
    end)

    total_bugs_count =
      maps
      |> Enum.reduce(0, fn {_level, map}, count ->
        GridMap.reduce(map, count, fn
          {{2, 2}, "?"}, count -> count
          {_, @bug}, count -> count + 1
          {_, @empty}, count -> count
        end)
      end)
      |> IO.inspect(label: "Total bugs")
  end

  @same_map 0
  @map_above -1
  @map_inside +1

  defp run_3d(maps, keyrange, minutes) do
    # at each iteration, we must extend the range of calculated map of 1 in each direction
    keyrange = (Enum.min(keyrange) - 1)..(Enum.max(keyrange) + 1)

    new_maps =
      keyrange
      |> Enum.reduce(%{}, fn map_key, new_maps ->
        map = Map.get_lazy(maps, map_key, &empty_map/0)

        new_map =
          GridMap.fmap(map, fn
            {2, 2}, _ ->
              # This is the "inside" map
              "?"

            coords, content ->
              bugs_count =
                coords
                |> get_neighbours_3d()
                |> Enum.reduce(0, fn {offset, coords}, acc ->
                  neighbour_map = Map.get_lazy(maps, map_key + offset, &empty_map/0)

                  case Map.get(neighbour_map, coords, @empty) do
                    @empty -> acc
                    @bug -> acc + 1
                  end
                end)

              evolve(content, bugs_count)
          end)

        Map.put(new_maps, map_key, new_map)
      end)

    run_3d(new_maps, keyrange, minutes - 1)
  end

  defp get_neighbours_3d({x, y}) do
    # in 3D, top row, bottom row, left column, right column has
    # neigbours one level above (towards negative infinity)
    # And vice versa.
    # We do not care if the neighbour cells exists or not, e.g. if x
    # is 0 we can still return x - 1
    # The first number of the returned coords is the offset for map keys

    top =
      case {x, y} do
        {_, 0} ->
          [{@map_above, {2, 1}}]

        {2, 3} ->
          [
            {@map_inside, {0, 4}},
            {@map_inside, {1, 4}},
            {@map_inside, {2, 4}},
            {@map_inside, {3, 4}},
            {@map_inside, {4, 4}}
          ]

        _ ->
          [{@same_map, {x, y - 1}}]
      end

    bottom =
      case {x, y} do
        {_, 4} ->
          [{@map_above, {2, 3}}]

        {2, 1} ->
          [
            {@map_inside, {0, 0}},
            {@map_inside, {1, 0}},
            {@map_inside, {2, 0}},
            {@map_inside, {3, 0}},
            {@map_inside, {4, 0}}
          ]

        _ ->
          [{@same_map, {x, y + 1}}]
      end

    left =
      case {x, y} do
        {0, _} ->
          [{@map_above, {1, 2}}]

        {3, 2} ->
          [
            {@map_inside, {4, 0}},
            {@map_inside, {4, 1}},
            {@map_inside, {4, 2}},
            {@map_inside, {4, 3}},
            {@map_inside, {4, 4}}
          ]

        _ ->
          [{@same_map, {x - 1, y}}]
      end

    right =
      case {x, y} do
        {4, _} ->
          [{@map_above, {3, 2}}]

        {1, 2} ->
          [
            {@map_inside, {0, 0}},
            {@map_inside, {0, 1}},
            {@map_inside, {0, 2}},
            {@map_inside, {0, 3}},
            {@map_inside, {0, 4}}
          ]

        _ ->
          [{@same_map, {x + 1, y}}]
      end

    :lists.flatten([top, left, right, bottom])
  end

  defp empty_map do
    """
    .....
    .....
    .....
    .....
    .....
    """
    |> GridMap.parse_map()
  end
end

"""
.....
...#.
.#..#
.#.#.
...##
"""

# """
# ....#
# #..#.
# #..##
# ..#..
# #....
# """
|> Day24.part2()
|> IO.inspect()

System.halt()
