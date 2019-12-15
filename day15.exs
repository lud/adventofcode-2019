defmodule Day15 do
  @unknown -1
  @wall 0
  @empty 1
  @system 2

  @north 1
  @south 2
  @west 3
  @east 4

  @init_coords {0, 0}

  def init() do
    map = set_map(empty_map(), @init_coords, @empty)

    %{xy: @init_coords, map: map, move_attempt: nil}
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

    direction =
      case get_unknown_neighbour(state) do
        {:ok, direction} ->
          direction

        :error ->
          read_input()
      end

    {direction, %{state | move_attempt: direction}}
  end

  def io({:output, @wall, state}) do
    wall_coords = attempted_coords(state)

    state
    |> set_map(wall_coords, @wall)
    |> no_attempt
  end

  def io({:output, @empty, state}) do
    state = finish_move(state)
    wall_coords = attempted_coords(state)

    state
    |> set_map(state.xy, @empty)
    |> no_attempt
  end

  def io(other) do
    raise "Unhandled io #{inspect(other)}"
  end

  defp finish_move(state) do
    new_coords = attempted_coords(state)
    state = %{state | xy: new_coords}
  end

  defp attempted_coords(%{xy: xy, move_attempt: attempt}) do
    move_coords(xy, attempt)
  end

  defp move_coords({x, y}, @north), do: {x, y - 1}
  defp move_coords({x, y}, @south), do: {x, y + 1}
  defp move_coords({x, y}, @east), do: {x + 1, y}
  defp move_coords({x, y}, @west), do: {x - 1, y}

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

  defp get_direction({from_x, from_y}, {from_x, new_y}) when new_y < from_y,
    do: @north

  defp get_direction({from_x, from_y}, {from_x, new_y}) when new_y > from_y,
    do: @south

  defp get_direction({from_x, from_y}, {new_x, from_y}) when new_x < from_x,
    do: @west

  defp get_direction({from_x, from_y}, {new_x, from_y}) when new_x > from_x,
    do: @east

  defp empty_map() do
    %{}
  end

  defp set_map(%{map: map} = state, coords, type) do
    map = set_map(map, coords, type)
    %{state | map: map}
  end

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

  defp print_map(map, droid) do
    {min_x, min_y} = min_coords(map)

    offset = {abs(min(min_x, 0)), abs(min(min_y, 0))}

    map_offset =
      Enum.map(map, fn {xy, v} -> {offset_xy(xy, offset), v} end)
      |> Enum.into(%{})

    draw_map(map_offset, offset_xy(droid, offset))
  end

  defp draw_map(map, droid) do
    {max_x, max_y} = max_coords(map)

    for y <- 0..max_y do
      [
        "\r",
        for x <- 0..max_x do
          case {x, y} do
            ^droid -> render_tile(:droid)
            _ -> render_tile(Map.get(map, {x, y}))
          end
        end,
        "\n"
      ]
    end
    |> IO.puts()

    map
  end

  defp render_tile(@unknown), do: [IO.ANSI.light_blue(), "?", IO.ANSI.reset()]
  defp render_tile(@wall), do: [IO.ANSI.light_red(), "#", IO.ANSI.reset()]
  defp render_tile(@system), do: "S"
  defp render_tile(@empty), do: "."
  defp render_tile(:droid), do: "D"
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

program =
  "day15.puzzle"
  |> File.read!()
  |> Cpu.run(io: &Day15.io/1, iostate: Day15.init())
