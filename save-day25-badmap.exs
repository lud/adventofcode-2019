defmodule Day25 do
  @puzzle "day25.puzzle" |> File.read!() |> Cpu.parse_intcodes()

  def part1 do
    iostate = %{
      input: [],
      output: [],
      map: %{},
      pos: nil,
      moves: [{0, 0}],
      inventory: [],
      action: :explore
    }

    Cpu.run(@puzzle, io: &io/1, iostate: iostate)
  end

  defp io({:output, val, state}) do
    IO.write([val])
    IOBuffer.push(state, :output, val)
  end

  @checkpoint {-3, 1}
  @gate {-3, 0}
  @avoided_rooms [
    # Pressure sensitive floor
    @gate
  ]

  @avoided_items [
    "giant electromagnet",
    "escape pod",
    "infinite loop",
    "molten lava"
  ]

  # raise """

  # The map is strange, 

  # we need a mapping for pathfinding as rooms are not squares, or overlap
  # """

  # input is empty, we must act on gatehered output and
  # ask for a new input buffer
  defp io({:input, %{input: [], output: output} = state}) do
    output = to_string(output)

    # IO.puts("""
    # -- OUPUT -------------------------------
    # #{output}
    # ----------------------------------------
    # """)

    state = IOBuffer.clear(state, :output)

    state =
      case parse_output(output) do
        # {:ok, []} ->

        {:ok, elements} ->
          IO.inspect(elements, label: :elements)

          state = Enum.reduce(elements, state, fn elem, state -> handle_parsed(state, elem) end)

          state = decide_next(state)
          print_map(state)
          IO.puts("next buffer: #{state.input}")
          # pause
          state
      end

    io({:input, state})
  end

  defp io({:input, %{input: [], output: output} = state}) do
    buffer =
      IO.gets("Input > ")
      |> to_charlist

    io({:input, IOBuffer.push(state, :input, buffer)})
  end

  defp io({:input, state}) do
    {val, state} = IOBuffer.take(state, :input)
    IO.write([val])
    {val, state}
  end

  defp handle_parsed(state, %{__type: :inventory, items: items}) do
    state
    |> Map.put(:inventory, items)
  end

  defp handle_parsed(state, %{__type: :room} = room) do
    {pos, state} = pop_move!(state)
    %{map: map} = state
    IO.puts("check room #{room.name} at #{inspect(pos)}")

    state
    |> Map.put(:pos, pos)
    |> Map.update!(:map, fn map ->
      case Map.get(map, pos) do
        %{__type: :room} ->
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

          IO.puts("Room registered")

          pause
          # map2 =
          #   case room do
          #     %{name: "Security Checkpoint"} -> Map.put(map2, :checkpoint, pos)
          #     _ -> map2
          #   end

          map2 =
            Enum.reduce(doors, map2, fn door, map2 ->
              neighbour_xy = move_coords(pos, door)
              Map.put_new(map2, neighbour_xy, :unknown_room)
            end)
      end
    end)
  end

  defp pop_move!(state) do
    {:ok, move, state} = pop_move(state)
    {move, state}
  end

  defp pop_move(%{moves: [move | moves]} = state) do
    {:ok, move, %{state | moves: moves}}
  end

  defp pop_move(%{moves: []} = _state) do
    :error
  end

  defp decide_next(%{action: :explore} = state) do
    %{map: map} = state

    unknown_room =
      GridMap.find(map, fn
        {coords, :unknown_room} when coords not in @avoided_rooms -> true
        _ -> false
      end)

    case unknown_room do
      {coords, :unknown_room} ->
        goto_room(state, coords)

      nil ->
        state
        |> Map.put(:action, :gather_items)
        |> decide_next()
    end
  end

  defp decide_next(%{action: :gather_items} = state) do
    %{map: map, inventory: inv} = state

    # Look for rooms with items that we do not have
    missing_items =
      GridMap.fmap(map, fn
        {_, _} = coords, %{__type: :room, items: items} ->
          _required_items = (items -- inv) -- @avoided_items

        {_, _} = coords, :unknown_room ->
          []
      end)
      # Filter the rooms that had items
      |> Enum.filter(fn
        {_, []} -> false
        {_, [_ | _]} -> true
      end)
      |> Enum.take(1)

    # |> IO.inspect(label: "items")

    case missing_items do
      [{coords, [item | _]}] ->
        state
        |> goto_room(coords)
        |> take_item(item)

      [] ->
        state
        |> Map.put(:action, :try_items)
        # |> IO.inspect()
        |> decide_next()
    end
  end

  defp decide_next(%{action: :try_items, inventory: inv} = state) do
    %{pos: {1, 2}} = state

    state
    # |> goto_room({-2, 1})
    |> goto_room(@checkpoint)
    # |> drop_all_items()
    |> Map.put(:action, {:try_items, inv})

    # |> goto_room(@gate)
  end

  defp decide_next(state) do
    # IO.puts("-- WHAT TO DO NEXT? --------")
    # IO.inspect(state, pretty: true)
    # IO.puts("----------------------------")
    # exit('input')
    interact(state, IO.gets("Input > "))
  end

  defp drop_all_items(state) do
    buffer =
      state.inventory
      |> Enum.map(&"drop #{&1}\n")
      |> Enum.join("")
      |> to_charlist

    IOBuffer.push(state, :input, buffer)
  end

  defp interact(state, input) do
    %{state | input: to_charlist(input)}
  end

  defp goto_room(%{moves: []} = state, coords) do
    %{pos: pos, map: map, moves: []} = state

    path =
      GridMap.get_path!(map, pos, coords,
        # unknown rooms are not walkable except if it is the
        # destination
        walkable?: fn
          _, %{__type: :room} -> true
          ^coords, _ -> true
          _, _ -> false
        end,
        neighbours: fn coords ->
          case Map.fetch(map, coords) do
            :error ->
              []

            {:ok, %{__type: :room, name: name, doors: doors} = room} ->
              # case name do
              # n -> IO.inspect("room #{name} leads to #{inspect(doors)}")
              # end

              for d <- doors, do: move_coords(coords, d)
          end
        end
      )

    IO.puts("starting from #{get_room_name(state, pos)}")

    IO.inspect(map)

    path
    |> Enum.map(fn coords ->
      IO.puts("#{inspect(coords)}: #{get_room_name(state, coords)}")
    end)

    # We have a path to our destination
    # We will create an input buffer and also register the positions
    # in :moves so when we parse the rooms we will be able to pop each
    # room position
    buffer = path_to_buffer([pos | path])

    state
    |> Map.put(:moves, path)
    |> IOBuffer.push(:input, buffer)
  end

  defp get_room_name(%{map: map}, pos) do
    case Map.fetch!(map, pos) do
      :unknown_room -> :unknown_room
      %{name: name} -> name
    end
  end

  defp take_item(state, item) do
    buffer = to_charlist("take #{item}\ninv\n")

    state = IOBuffer.push(state, :input, buffer)
    # |> IO.inspect()

    state
  end

  # defp require_item(%{try_items: required_items}, items) do
  #   unrequired = items -- required_items

  #   required =
  #     (items -- unrequired)
  #     |> IO.inspect(label: "Required items")

  #   case required do
  #     [] -> :error
  #     [req | _] -> {:ok, req}
  #   end
  # end

  # defp take_item(item, state) do
  #   buffer = 'take ' ++ to_charlist(item) ++ '\ninv\n'
  #   io({:input, %{state | input: buffer, inventory: [item | state.inventory]}})
  # end

  defp pause() do
    IO.gets("-- Pause ----------------------------------------------")
  end

  # defp continue_explore(state, room) do
  #   %{pos: pos, output: output, map: map, track: track} = state

  #   next_rooms =
  #     room
  #     |> Map.get(:doors)
  #     |> Enum.map(&move_coords(pos, &1))
  #     |> Enum.filter(fn
  #       coords when coords in @avoided_rooms -> false
  #       coords -> Map.get(map, coords, :unknown_room) == :unknown_room
  #     end)

  #   case next_rooms do
  #     [] ->
  #       case track do
  #         [] ->
  #           if all_items_found?(state) do
  #             IO.puts("All required items found")
  #             # try_entering(state)
  #           end

  #         [prev | ntrack] ->
  #           IO.puts("backtracking")
  #           IO.inspect(pos, label: :pos)
  #           IO.inspect(track, label: :track)
  #           next_command = direction_buffer(pos, prev)

  #           state
  #           |> Map.merge(%{pos: prev, input: next_command, track: ntrack})
  #           |> (&io({:input, &1})).()
  #       end

  #     [next_room | _] ->
  #       next_command = direction_buffer(pos, next_room)

  #       state
  #       |> track_pos()
  #       |> Map.merge(%{pos: next_room, input: next_command})
  #       |> (&io({:input, &1})).()
  #   end
  # end

  # defp all_items_found?(%{inventory: inv, try_items: try_items}) do
  #   [] == try_items -- inv
  # end

  # defp print_items(%{map: map}) do
  #   IO.puts("All found items")

  #   map
  #   |> Enum.map(fn
  #     {_, %{items: items}} -> items
  #     {_, :unknown_room} -> []
  #   end)
  #   |> :lists.flatten()
  #   |> Enum.map(&IO.puts/1)
  # end

  # defp track_pos(%{track: track, pos: pos} = state) do
  #   IO.puts("tracking #{inspect(pos)} on top of #{inspect(track)}")
  #   %{state | track: [pos | track]}
  # end

  defp path_to_buffer([_last]),
    do: []

  defp path_to_buffer([from, to | path]),
    do: direction_buffer(from, to) ++ path_to_buffer([to | path])

  defp direction_buffer({x, y1}, {x, y2}) when y2 == y1 - 1,
    do: 'north\n'

  defp direction_buffer({x, y1}, {x, y2}) when y2 == y1 + 1,
    do: 'south\n'

  defp direction_buffer({x1, y}, {x2, y}) when x2 == x1 - 1,
    do: 'west\n'

  defp direction_buffer({x1, y}, {x2, y}) when x2 == x1 + 1,
    do: 'east\n'

  defp parse_output(output) when is_binary(output) do
    output
    |> to_string
    |> String.trim()
    |> String.split("\n")
    |> parse_output
  end

  defp parse_output(["" | lines]),
    do: parse_output(lines)

  defp parse_output(lines) when is_list(lines),
    do: parse_output(lines, [])

  defp parse_output(lines, elements) do
    case lines do
      ["==" <> _ | _] ->
        {%{__type: :room} = room, lines} = parse_room(lines)
        parse_output(lines, [room | elements])

      ["Command?" | lines] ->
        parse_output(lines, elements)

      ["" | lines] ->
        parse_output(lines, elements)

      ["You take the " <> _ | lines] ->
        # ignore as we will parse inventory
        parse_output(lines, elements)
        parse_output(lines, elements)

      ["Items in your inventory:" | lines] ->
        {%{__type: :inventory} = inv, lines} = parse_inventory(lines)
        parse_output(lines, [inv | elements])

      [] ->
        {:ok, :lists.reverse(elements)}
    end
  end

  defp parse_room(lines) do
    base_room = %{__type: :room, items: [], doors: []}

    parse_room(lines, base_room)
  end

  @re_room ~r/(.+) ==$/
  # Discard empty lines
  defp parse_room(["" | lines], room),
    do: parse_room(lines, room)

  # parse the room name
  defp parse_room(["== " <> room_name, description | lines], room) do
    [room_name | _] = Regex.run(@re_room, room_name, capture: :all_but_first)
    room = Map.merge(room, %{name: room_name, description: description})
    parse_room(lines, room)
  end

  # parse the doors
  defp parse_room(["Doors here lead:" | lines], room) do
    {doors, lines} = parse_doors(lines, [])
    room = Map.put(room, :doors, doors)
    parse_room(lines, room)
  end

  # parse the items
  defp parse_room(["Items here:" | lines], room) do
    {items, lines} = parse_items(lines, [])
    room = Map.put(room, :items, items)
    parse_room(lines, room)
  end

  # Parse is finished
  defp parse_room(["Command?" | lines], room) do
    {room, lines}
  end

  defp parse_room([], room) do
    {room, []}
  end

  defp parse_room(lines, room) do
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

  defp parse_inventory(lines) do
    {items, lines} = parse_items(lines, [])
    {%{__type: :inventory, items: items}, lines}
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
