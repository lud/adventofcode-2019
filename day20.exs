defmodule Day20 do
  @void 32
  @empty ?.
  @wall ?#
  @add_y 140

  defguard is_portal_mark(x) when x >= ?A and x <= ?Z
  defguard is_empty(x) when x == @empty

  def run(puzzle) do
    " " <> p = puzzle
    # prevent trimming the map
    puzzle = "#" <> p
    map = GridMap.parse_map(puzzle, &parse_char/2)

    GridMap.render_map(map, fn
      _, nil -> " "
      _, n -> n
    end)
    |> Enum.intersperse(?\n)
    |> IO.puts()

    locations =
      get_locations(map)
      |> IO.inspect()

    entry = Map.fetch!(locations, :entry)
    finish = Map.fetch!(locations, :finish)

    path =
      GridMap.get_path!(map, entry, finish,
        walkable?: fn
          @empty -> true
          _ -> false
        end,
        neighbours: fn xy ->
          cardinal = GridMap.cardinal_neighbours(xy)

          case Map.get(locations, xy) do
            {:portal, name, other_end} ->
              IO.puts("will teleport #{inspect(xy)} => #{name} => #{inspect(other_end)}")
              [other_end | cardinal]

            _ ->
              cardinal
          end
        end,
        heuristic: fn _, _ -> 0 end
      )

    xstep = [IO.ANSI.red(), "X", IO.ANSI.reset()]
    entry_map = Map.put(map, entry, xstep)

    path
    |> Enum.reduce(entry_map, fn xy, map -> Map.put(map, xy, xstep) end)
    |> GridMap.render_map(fn
      _, nil -> " "
      _, n -> n
    end)
    |> Enum.intersperse(?\n)
    |> IO.puts()

    IO.inspect(length(path), label: "Steps")
  end

  defp parse_char(_, @void),
    do: :ignore

  # defp parse_char(_, char) when is_portal_mark(char),
  #   do: char

  defp parse_char(_, char),
    do: char

  defp get_locations(map) do
    # To get the portals we will look into the map to find all portal
    # marks.
    # Then we will look up/down/left/right to find another mark
    # If found, we will go one cell further in that direction, and if
    # we find @empty we have found a portal.
    # If we have 'HT.' and we start on 'T', then try left (find 'H')
    # then try left again to find '.' but there is not, we just skip,
    # as the alogorithm will eventually start on 'H' and when going 
    # ->right it will work.
    # We will read all those coords, current cell is X
    #               up2
    #               up1
    # left2 left2   X    right1 right 2
    #               down1
    #               down2
    #         
    # 
    GridMap.reduce(map, [], fn
      {coords, mark}, list when is_portal_mark(mark) ->
        up1 = Map.get(map, GridMap.move_coords(coords, :up, 1))
        up2 = Map.get(map, up2_xy = GridMap.move_coords(coords, :up, 2))
        down1 = Map.get(map, GridMap.move_coords(coords, :down, 1))
        down2 = Map.get(map, down2_xy = GridMap.move_coords(coords, :down, 2))
        left1 = Map.get(map, GridMap.move_coords(coords, :left, 1))
        left2 = Map.get(map, left2_xy = GridMap.move_coords(coords, :left, 2))
        right1 = Map.get(map, GridMap.move_coords(coords, :right, 1))
        right2 = Map.get(map, right2_xy = GridMap.move_coords(coords, :right, 2))

        [
          parse_portal(coords, mark, :up, up1, up2, up2_xy),
          parse_portal(coords, mark, :down, down1, down2, down2_xy),
          parse_portal(coords, mark, :left, left1, left2, left2_xy),
          parse_portal(coords, mark, :right, right1, right2, right2_xy)
        ]
        |> Enum.filter(fn
          {:ok, portal} -> true
          _ -> false
        end)
        |> Enum.map(fn {:ok, p} -> p end)
        |> case do
          [portal] -> [portal | list]
          [] -> list
        end

      {_, _}, list ->
        list
    end)
    |> Enum.group_by(fn {coord, name} -> name end)
    |> Enum.reduce(%{}, fn
      {"AA", [{xy, "AA"}]}, acc ->
        acc
        |> Map.put(xy, :entry)
        |> Map.put(:entry, xy)

      {"ZZ", [{xy, "ZZ"}]}, acc ->
        acc
        |> Map.put(xy, :finish)
        |> Map.put(:finish, xy)

      {name, [{xy1, name}, {xy2, name}]}, acc ->
        acc |> Map.put(xy1, {:portal, name, xy2}) |> Map.put(xy2, {:portal, name, xy1})
    end)
  end

  # beware order of letters for the names
  defp parse_portal(origin, mark, :up, up1, up2, xy)
       when is_portal_mark(up1) and is_empty(up2),
       do: {:ok, {xy, List.to_string([up1, mark])}}

  defp parse_portal(origin, mark, :left, left1, left2, xy)
       when is_portal_mark(left1) and is_empty(left2),
       do: {:ok, {xy, List.to_string([left1, mark])}}

  defp parse_portal(origin, mark, :down, down1, down2, xy)
       when is_portal_mark(down1) and is_empty(down2),
       do: {:ok, {xy, List.to_string([mark, down1])}}

  defp parse_portal(origin, mark, :right, right1, right2, xy)
       when is_portal_mark(right1) and is_empty(right2),
       do: {:ok, {xy, List.to_string([mark, right1])}}

  defp parse_portal(_, _, _, _, _, _),
    do: :error
end

"day20.puzzle"
|> File.read!()
|> Day20.run()
|> IO.inspect()

System.halt()
