defmodule Day25 do
  @puzzle "day25.puzzle" |> File.read!() |> Cpu.parse_intcodes()

  def part1 do
    try_with_items(["planetoid"])
  end

  defp try_with_items(items) do
    iostate = %{
      input: [],
      output: [],
      map: %{},
      pos: {0, 0},
      track: [],
      inventory: [],
      try_items: items
    }

    Cpu.run(@puzzle, io: &io/1, iostate: iostate)
  end

  defp io({:output, val, state}) do
    IO.write([val])
    IOBuffer.push(state, :output, val)
  end

  @avoidance_list [
    # Pressure sensitive floor
    # {-3, 0}
  ]

  # input is empty, we must act on gatehered output and
  # ask for a new input buffer
  defp io({:input, %{input: [], output: output} = state}) do
    state = IOBuffer.clear(state, :output)
    pause()

    case parse_room(output) do
      {:ok, room} -> enter_room(room, state)
    end
    |> case do
      {val, state} when is_integer(val) -> {val, state}
      other -> exit({:bad_input_res, other})
    end
  end

  defp io({:input, state}) do
    {val, state} = IOBuffer.take(state, :input)
    IO.write([val])
    {val, state}
  end

  defp enter_room(room, state) do
    room = Map.put(room, :track, state.track)

    state =
      state
      |> update_map(room)
      |> print_map()

    case require_item(state, room.items) do
      {:ok, item} ->
        take_item(item, state)

      :error ->
        continue_explore(state, room)
    end
  end

  defp require_item(%{try_items: required_items}, items) do
    unrequired = items -- required_items

    required =
      (items -- unrequired)
      |> IO.inspect(label: "Required items")

    case required do
      [] -> :error
      [req | _] -> {:ok, req}
    end
  end

  defp take_item(item, state) do
    buffer = 'take ' ++ to_charlist(item) ++ '\ninv\n'
    io({:input, %{state | input: buffer, inventory: [item | state.inventory]}})
  end

  defp pause() do
    IO.gets("Pause")
  end

  defp continue_explore(state, room) do
    %{pos: pos, output: output, map: map, track: track} = state

    next_rooms =
      room
      |> Map.get(:doors)
      |> Enum.map(&move_coords(pos, &1))
      |> Enum.filter(fn
        coords when coords in @avoidance_list -> false
        coords -> Map.get(map, coords, :unknown_room) == :unknown_room
      end)

    case next_rooms do
      [] ->
        case track do
          [] ->
            if all_items_found?(state) do
              IO.puts("All required items found")
              # try_entering(state)
            end

          [prev | ntrack] ->
            IO.puts("backtracking")
            IO.inspect(pos, label: :pos)
            IO.inspect(track, label: :track)
            next_command = direction_buffer(pos, prev)

            state
            |> Map.merge(%{pos: prev, input: next_command, track: ntrack})
            |> (&io({:input, &1})).()
        end

      [next_room | _] ->
        next_command = direction_buffer(pos, next_room)

        state
        |> track_pos()
        |> Map.merge(%{pos: next_room, input: next_command})
        |> (&io({:input, &1})).()
    end
  end

  defp all_items_found?(%{inventory: inv, try_items: try_items}) do
    [] == try_items -- inv
  end

  defp print_items(%{map: map}) do
    IO.puts("All found items")

    map
    |> Enum.map(fn
      {_, %{items: items}} -> items
      {_, :unknown_room} -> []
    end)
    |> :lists.flatten()
    |> Enum.map(&IO.puts/1)
  end

  defp track_pos(%{track: track, pos: pos} = state) do
    IO.puts("tracking #{inspect(pos)} on top of #{inspect(track)}")
    %{state | track: [pos | track]}
  end

  defp direction_buffer({x, y1}, {x, y2}) when y2 == y1 - 1,
    do: 'north\n'

  defp direction_buffer({x, y1}, {x, y2}) when y2 == y1 + 1,
    do: 'south\n'

  defp direction_buffer({x1, y}, {x2, y}) when x2 == x1 - 1,
    do: 'west\n'

  defp direction_buffer({x1, y}, {x2, y}) when x2 == x1 + 1,
    do: 'east\n'

  defp parse_room(output) do
    lines =
      output
      |> to_string
      |> String.split("\n")

    base_room = %{__room__: true, items: [], doors: []}

    case parse(lines, base_room) do
      # Todo check special rooms
      %{__room__: true} = room ->
        {:ok, room}

      {%{__room__: true} = room, lines} ->
        IO.warn("Unparsed : #{lines}")
        {:ok, room}
    end
  end

  @re_room ~r/(.+) ==$/
  # Discard empty lines
  defp parse(["" | lines], room),
    do: parse(lines, room)

  # parse the room name
  defp parse(["== " <> room_name, description | lines], room) do
    [room_name | _] = Regex.run(@re_room, room_name, capture: :all_but_first)
    room = Map.merge(room, %{name: room_name, description: description})
    parse(lines, room)
  end

  # parse the doors
  defp parse(["Doors here lead:" | lines], room) do
    {doors, lines} = parse_doors(lines, [])
    room = Map.put(room, :doors, doors)
    parse(lines, room)
  end

  # parse the items
  defp parse(["Items here:" | lines], room) do
    {items, lines} = parse_items(lines, [])
    room = Map.put(room, :items, items)
    parse(lines, room)
  end

  # Parse is finished
  defp parse(["Command?" | _], room) do
    room
  end

  defp parse([], room) do
    room
  end

  defp parse(lines, room) do
    {room, lines}
  end

  defp parse_doors(["- " <> cardinal | lines], acc),
    do: parse_doors(lines, [String.to_atom(cardinal) | acc])

  defp parse_doors(["" | lines], acc),
    do: {acc, lines}

  defp parse_items(["- " <> item | lines], acc),
    do: parse_items(lines, [item | acc])

  defp parse_items(["" | lines], acc),
    do: {acc, lines}

  defp update_map(state, room) do
    %{pos: pos, map: map} = state

    map =
      case Map.get(map, pos) do
        %{__room__: true} ->
          # this room is known
          IO.puts("Known room")
          map

        unknown when unknown in [nil, :unknown_room] ->
          # This is a new room, we add it to the map at the current
          # position, and alsso add an :unknown_room for each
          # corresponding door, if the room is not already known in the
          # map
          %{doors: doors} = room

          map2 = Map.put(map, pos, room)

          map2 =
            case room do
              %{name: "Security Checkpoint"} -> Map.put(map2, :checkpoint, pos)
              _ -> map2
            end

          map2 =
            Enum.reduce(doors, map2, fn door, map2 ->
              neighbour_xy = move_coords(pos, door)
              Map.put_new(map2, neighbour_xy, :unknown_room)
            end)
      end

    %{state | map: map}
  end

  defp move_coords({x, y}, :north), do: {x, y - 1}
  defp move_coords({x, y}, :south), do: {x, y + 1}
  defp move_coords({x, y}, :east), do: {x + 1, y}
  defp move_coords({x, y}, :west), do: {x - 1, y}

  defp print_map(%{pos: pos} = state) do
    GridMap.print_map(state.map, &render_tile(&1, &2, pos))
    state
  end

  defp render_tile(_, nil, _), do: " "
  defp render_tile(_, :unknown_room, _), do: "?"
  defp render_tile(pos, _, pos), do: "X"
  defp render_tile({0, 0}, _, _), do: "R"
  defp render_tile(_, _, _), do: "O"
end

Day25.part1()

System.halt()
