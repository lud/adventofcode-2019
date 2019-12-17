defmodule Day15 do
  @unknown -1
  @wall 0
  @empty 1
  @system 2
  @oxygen 3

  @north 1
  @south 2
  @west 3
  @east 4

  @init_coords {0, 0}

  def init() do
    map = set_map(empty_map(), @init_coords, @empty)
    # print_map(map, @init_coords)
    %{xy: @init_coords, map: map, move_attempt: nil, track: []}
  end

  defp read_input(prompt \\ "move > ") do
    case String.trim(IO.gets(prompt)) do
      "q" -> @west
      "z" -> @north
      "d" -> @east
      "s" -> @south
      other -> read_input("error ! move > ")
    end
  end

  def io({:input, state}) do
    print_map(state.map, state.xy)

    case get_unknown_neighbour(state) do
      {:ok, direction} ->
        {direction, %{state | move_attempt: direction}}

      :error ->
        {_direction, _state} = backtrack(state)
        # IO.ANSI.clear() |> IO.write()
        # IO.inspect(state.track)
        # exit(:ok)
        # read_input()
    end
  end

  def io({:output, @wall, state}) do
    wall_coords = attempted_coords(state)

    state
    |> set_map(wall_coords, @wall)
    |> no_attempt
  end

  def io({:output, type, state}) when type in [@empty, @system] do
    # draw the old position of the droid as empty. @todo check if it
    # oxygen system
    state = finish_move(state)

    if type == @system do
      send(self(), {:found, state.track})
    end

    state
    |> set_map(state.xy, type)
    |> no_attempt
  end

  def io(other) do
    raise "Unhandled io #{inspect(other)}"
  end

  defp finish_move(%{move_attempt: {:backtrack, direction}} = state) do
    new_coords = attempted_coords(state)
    state = %{state | xy: new_coords}
  end

  defp finish_move(state) do
    new_coords = attempted_coords(state)
    track = [state.move_attempt | state.track]
    state = %{state | xy: new_coords, track: track}
  end

  defp attempted_coords(%{xy: xy, move_attempt: {:backtrack, direction}}) do
    move_coords(xy, direction)
  end

  defp attempted_coords(%{xy: xy, move_attempt: direction}) do
    move_coords(xy, direction)
  end

  defp backtrack(%{track: []} = state) do
    print_map(state.map, state.xy)
    throw({:finished, state})
  end

  defp backtrack(%{track: [direction | track]} = state) do
    direction = reverse_direction(direction)

    {
      direction,
      %{state | track: track, move_attempt: {:backtrack, direction}}
    }
  end

  defp reverse_direction(@north), do: @south
  defp reverse_direction(@south), do: @north
  defp reverse_direction(@east), do: @west
  defp reverse_direction(@west), do: @east

  defp get_unknown_neighbour(state) do
    xy = state.xy

    found =
      Enum.find(state.map, :error, fn
        {coords, @unknown} -> neighbour?(coords, xy)
        {_, _} -> false
      end)

    case found do
      :error -> :error
      {coords, @unknown} -> {:ok, get_direction(xy, coords)}
    end
  end

  defp neighbour?({x, y}, {x, y2}) when abs(y - y2) == 1, do: true
  defp neighbour?({x, y}, {x2, y}) when abs(x - x2) == 1, do: true
  defp neighbour?(_, _), do: false

  defp get_direction({from_x, from_y}, {from_x, new_y})
       when new_y < from_y,
       do: @north

  defp get_direction({from_x, from_y}, {from_x, new_y})
       when new_y > from_y,
       do: @south

  defp get_direction({from_x, from_y}, {new_x, from_y})
       when new_x < from_x,
       do: @west

  defp get_direction({from_x, from_y}, {new_x, from_y})
       when new_x > from_x,
       do: @east

  defp empty_map() do
    %{}
  end

  defp set_map(%{map: map} = state, coords, type) do
    map = set_map(map, coords, type)
    %{state | map: map}
  end

  defp set_map(map, coords, @oxygen),
    do: Map.put(map, coords, @oxygen)

  defp set_map(map, coords, @unknown),
    do: Map.put(map, coords, @unknown)

  defp set_map(map, coords, @wall),
    do: Map.put(map, coords, @wall)

  defp set_map(map, coords, type) do
    map = Map.put(map, coords, type)

    coords
    |> cardinal_neighbors()
    |> Enum.reduce(map, &set_map_new(&2, &1, @unknown))
  end

  defp set_map_new(map, coords, type) do
    if Map.has_key?(map, coords) do
      map
    else
      set_map(map, coords, type)
    end
  end

  defp move_coords({x, y}, @north), do: {x, y - 1}
  defp move_coords({x, y}, @south), do: {x, y + 1}
  defp move_coords({x, y}, @east), do: {x + 1, y}
  defp move_coords({x, y}, @west), do: {x - 1, y}

  defp cardinal_neighbors({_, _} = coords) do
    [
      move_coords(coords, @north),
      move_coords(coords, @south),
      move_coords(coords, @east),
      move_coords(coords, @west)
    ]
  end

  defp no_attempt(state) do
    %{state | move_attempt: nil}
  end

  defp print_map(map, droid \\ nil) do
    draw_map(map, droid)
    {:ok, :printed}
  end

  def run_oxygen(map) do
    {coords, @system} =
      Enum.find(map, fn
        {_, @system} -> true
        _ -> false
      end)

    map = set_map(map, coords, @oxygen)

    print_map(map)

    fringe =
      [coords]
      |> IO.inspect()

    run_oxygen(map, fringe, 0)
  end

  defp run_oxygen(map, [], count) do
    print_map(map)
    {:filled, count}
  end

  defp run_oxygen(map, fringe, count) do
    new_fringe =
      fringe
      |> Enum.flat_map(&get_empty_neighbours(&1, map))

    map = Enum.reduce(new_fringe, map, fn coords, map -> set_map(map, coords, @oxygen) end)

    new_fringe
    |> Enum.each(&draw_tile(&1, @oxygen))

    Process.sleep(10)

    case new_fringe do
      [] ->
        [IO.ANSI.cursor(45, 0), "Done\n"] |> IO.write()
        {:filled, count}

      _ ->
        run_oxygen(map, new_fringe, count + 1)
    end
  end

  defp get_empty_neighbours(coords, map) do
    coords
    |> cardinal_neighbors
    |> Enum.filter(&(Map.get(map, &1) == @empty))
  end

  defp draw_map(map, droid \\ nil) do
    {min_x, min_y} = min_coords(map)
    {max_x, max_y} = max_coords(map)
    offset = {abs(min(min_x, 0)) + 2, abs(min(min_y, 0)) + 2}
    old_offset = Process.put(:draw_offset, offset)

    if old_offset != offset do
      IO.write(IO.ANSI.clear())
    end

    for y <- min_y..max_y do
      for x <- min_x..max_x do
        draw_tile({x, y}, Map.get(map, {x, y}))
      end
    end

    if droid != nil do
      draw_tile(droid, :droid)
    end
  end

  defp draw_tile({x, y}, tile) do
    {offset_x, offset_y} = Process.get(:draw_offset, {0, 0})

    [
      IO.ANSI.cursor(y + offset_y, x + offset_x),
      render_tile(tile)
    ]
    |> IO.write()
  end

  defp render_tile(@unknown), do: [IO.ANSI.light_blue(), "?", IO.ANSI.reset()]
  defp render_tile(@wall), do: [IO.ANSI.yellow(), "■", IO.ANSI.reset()]
  defp render_tile(@system), do: [IO.ANSI.green_background(), "S", IO.ANSI.reset()]
  defp render_tile(@empty), do: " "
  defp render_tile(:droid), do: "X"
  defp render_tile(@oxygen), do: [IO.ANSI.blue_background(), "~", IO.ANSI.reset()]
  defp render_tile(nil), do: " "

  defp offset_xy({x, y}, {ax, ay}) do
    {x + ax, y + ay}
  end

  defp max_coords(map) do
    map
    |> Map.keys()
    |> Enum.reduce(fn {x, y}, {max_x, max_y} ->
      {max(x, max_x), max(y, max_y)}
    end)
  end

  defp min_coords(map) do
    map
    |> Map.keys()
    |> Enum.reduce(fn {x, y}, {min_x, min_y} ->
      {min(x, min_x), min(y, min_y)}
    end)
  end
end

program = File.read!("day15.puzzle")

map =
  try do
    Cpu.run(program, io: &Day15.io/1, iostate: Day15.init())
  catch
    {:finished, state} ->
      [IO.ANSI.cursor(45, 0), "Done\n"] |> IO.write()

      receive do
        {:found, track} ->
          IO.puts("path length: #{length(track)}")
          state.map
      end
  end

Day15.run_oxygen(map)
|> IO.inspect()
