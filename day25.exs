defmodule Day25 do
  @puzzle "day25.puzzle" |> File.read!() |> Cpu.parse_intcodes()

  @avoided_items [
    "giant electromagnet",
    "escape pod",
    "infinite loop",
    "molten lava",
    "photons"
  ]

  def part1 do
    iostate = %{
      input: [],
      output: [],
      items: %{},
      rooms: %{},
      paths: %{},
      from_pos: nil,
      chapter: :explore,
      current_room: nil,
      actions: [{:expect_room, "Hull Breach"}]
    }

    Cpu.run(@puzzle, io: &io/1, iostate: iostate)
  end

  defp io({:output, val, state}) do
    IO.write([val])
    IOBuffer.push(state, :output, val)
  end

  defp io({:input, %{actions: [], chapter: chapter} = state}) do
    state = create_actions(chapter, state)
    io({:input, state})
  end

  defp io({:input, %{actions: actions, output: output, input: []} = state}) do
    state =
      state
      |> IOBuffer.clear(:output)
      |> Map.put(:actions, [])

    lines = prepare_output(output)

    {state, []} =
      Enum.reduce(actions, {state, lines}, fn action, {state, lines} ->
        {action_data, lines} = parse_action(action, lines)
        state = apply_action(action_data.__type, action_data, state)
        {state, lines}
      end)

    io({:input, state})
  end

  defp io({:input, state}) do
    {val, state} = IOBuffer.take(state, :input)
    IO.write([val])
    {val, state}
  end

  defp prepare_output(charlist) do
    charlist
    |> to_string
    |> String.trim()
    |> String.split("\n")
  end

  defp push_action(state, action) do
    %{actions: actions} = state
    %{state | actions: actions ++ [action]}
  end

  defp parse_action({:take_door, room, dir}, lines) do
    {%{__type: :door_taken, room: room, dir: dir}, lines}
  end

  defp parse_action({:expect_room, name}, lines) do
    {room, lines} = parse_action(:explore_room, lines)

    if room.name != name do
      raise "Unexpected room #{room.name}, expected #{name}"
    end

    {room, lines}
  end

  defp parse_action(:explore_room, lines) do
    {room, lines} = parse_room(lines)

    {room, lines}
  end

  defp parse_action({:take_item, item}, lines) do
    {^item, lines} = parse_item_pickup(lines)
    {%{__type: :pickup, item: item}, lines}
  end

  defp parse_action({:drop_item, item}, lines) do
    {^item, lines} = parse_item_drop(lines)
    {%{__type: :drop, item: item}, lines}
  end

  defp parse_item_pickup(["" | lines]),
    do: parse_item_pickup(lines)

  defp parse_item_pickup(["You take the " <> item, "", "Command?" | lines]) do
    item = String.slice(item, 0..-2)
    {item, lines}
  end

  defp parse_item_drop(["" | lines]),
    do: parse_item_drop(lines)

  defp parse_item_drop(["You drop the " <> item, "", "Command?" | lines]) do
    item = String.slice(item, 0..-2)
    {item, lines}
  end

  defp parse_room(lines) do
    base_room = %{__type: :room, items: [], doors: []}

    parse_room(lines, base_room)
  end

  @re_room ~r/(.+) ==$/
  # Discard empty lines
  defp parse_room(["" | lines], room),
    do: parse_room(lines, room)

  defp parse_room(["A loud, robotic voice says \"Alert!" <> _ | lines], room) do
    # we failed the pressure test
    # we will be teleported to the security checkpoint, and it is
    # present in the output
    {next_room, lines} = parse_room(lines)
    data = %{__type: :teleport, rooms: {room, next_room}}
    {data, lines}
  end

  # parse the room name
  defp parse_room(["== " <> room_name, description | lines], room) do
    [room_name | _] = Regex.run(@re_room, room_name, capture: :all_but_first)
    room = Map.merge(room, %{name: room_name, description: description})
    parse_room(lines, room)
  end

  # parse the doors
  defp parse_room(["" | lines], room) do
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

  # defp parse_room(lines, room) do
  #   {room, lines}
  # end

  defp parse_doors(["- " <> cardinal | lines], acc),
    do: parse_doors(lines, [String.to_atom(cardinal) | acc])

  defp parse_doors(["" | lines], acc),
    do: {acc, lines}

  defp parse_items(["- " <> item | lines], acc),
    do: parse_items(lines, [item | acc])

  defp parse_items(["" | lines], acc),
    do: {acc, lines}

  defp apply_action(:teleport, %{rooms: {room_a, room_b}}, state) do
    {from_room, door} = state.from_pos
    %{name: ^from_room} = room_b
    # apply the entered room (pressure floor)
    state = apply_action(:room, room_a, state)
    # we are theleported so we set the from_pos to the pressure floor
    state = Map.put(state, :from_pos, {room_a.name, reverse_direction(door)})
    # then we can apply the security checkpoint room
    state = apply_action(:room, room_b, state)
  end

  defp apply_action(:door_taken, %{room: room, dir: dir}, state) do
    Map.put(state, :from_pos, {room, dir})
  end

  defp apply_action(:pickup, %{item: item}, state) do
    put_in(state, [:items, item], :carried)
  end

  defp apply_action(:drop, %{item: item}, state) do
    put_in(state, [:items, item], state.current_room)
  end

  defp apply_action(:room, room, state) do
    %{name: room_name, items: room_items, doors: doors} = room

    state =
      state
      # Set current position
      |> Map.put(:current_room, room_name)
      # Update the rooms
      |> put_in([:rooms, room_name], room)
      # Update items
      |> Map.update!(:items, fn state_items ->
        Enum.reduce(room_items, state_items, fn room_item, state_items ->
          Map.put(state_items, room_item, room_name)
        end)
      end)
      |> Map.update!(:paths, fn paths ->
        doors
        |> Enum.reduce(paths, fn door, paths ->
          register_path(paths, room_name, door, :unknown_room)
        end)
      end)

    state =
      case state.from_pos do
        nil ->
          state

        {from_room, from_dir} ->
          state
          |> register_path(from_room, from_dir, room_name)
          |> register_path(room_name, reverse_direction(from_dir), from_room)
      end
  end

  defp reverse_direction(:north), do: :south
  defp reverse_direction(:south), do: :north
  defp reverse_direction(:east), do: :west
  defp reverse_direction(:west), do: :east

  defp register_path(%{paths: paths} = state, room_name, door, destination) do
    %{state | paths: register_path(paths, room_name, door, destination)}
  end

  defp register_path(paths, room_name, door, destination) do
    paths
    |> Map.put_new(room_name, %{})
    |> update_in([room_name, door], fn current ->
      case {current, destination} do
        {known, :unknown_room} when is_binary(known) ->
          # IO.puts("not erasing path #{room_name} -- #{door} --> #{known}")
          known

        {same, same} ->
          # IO.puts("already known #{room_name} -- #{door} --> #{same}")
          same

        {nil, :unknown_room} ->
          # IO.puts("register door: #{room_name} -- #{door} --> #{destination}")
          destination

        {:unknown_room, destination} ->
          # IO.puts("register door: #{room_name} -- #{door} --> #{destination}")
          destination
      end
    end)
  end

  defguard is_direction(x) when x in [:north, :south, :east, :west]

  defp create_actions(:explore, state) do
    %{current_room: current_room, paths: paths} = state

    # Look for unknown rooms
    doors_with_doors_to_unknown =
      paths
      |> Enum.reduce(%{}, fn {room, doors_to_rooms}, acc ->
        doors_to_rooms
        |> Enum.filter(fn
          {direction, :unknown_room} when is_direction(direction) -> true
          other -> false
        end)
        |> case do
          [] -> acc
          unknowns -> Map.put(acc, room, unknowns)
        end
      end)

    if 0 == Map.size(doors_with_doors_to_unknown) do
      Map.put(state, :chapter, :gather_items)
    else
      # If we can explore from the current room we will, otherwise
      # we must go to another room before

      case Map.fetch(doors_with_doors_to_unknown, current_room) do
        {:ok, [{direction, :unknown_room} | _]} ->
          explore_door(current_room, direction, state)

        :error ->
          [{destination, [{_, :unknown_room} | _]}] = Enum.take(doors_with_doors_to_unknown, 1)

          goto_room(state, destination)
      end
    end
  end

  defp create_actions(:gather_items, state) do
    # We must calculate items one by one because we need the current 
    # position after each item is picked up.
    state
    |> Map.get(:items)
    |> Enum.filter(fn
      {item, room} when item in @avoided_items -> false
      {_, :carried} -> false
      _ -> true
    end)
    |> case do
      [] ->
        Map.put(state, :chapter, :try_items)

      [{item, room} | _] ->
        state
        |> goto_room(room)
        |> take_item(item)
    end
  end

  defp create_actions(:try_items, state) do
    carried = carried_items(state)

    works =
      1..4
      |> Enum.map(&combinations(carried, &1))
      |> :lists.flatten()

    state
    |> goto_room("Security Checkpoint")
    |> drop_carried_items()
    |> Map.put(:chapter, {:try_items, carried, works})
  end

  defp create_actions({:try_items, tryables, []}, state) do
    exit(:no_work)
  end

  defp create_actions({:try_items, tryables, [work | works]}, state) do
    case state.current_room do
      "Pressure-Sensitive Floor" ->
        exit(:WIIIIIIIN)

      "Security Checkpoint" ->
        state = drop_carried_items(state)
        {:combination, items} = work
        IO.puts("will try #{inspect(items)}")

        state =
          items
          |> Enum.reduce(state, fn item, state -> take_item(state, item) end)
          |> goto_room("Pressure-Sensitive Floor")
          |> Map.put(:chapter, {:try_items, tryables, works})
    end
  end

  defp carried_items(state) do
    carried =
      state.items
      |> Enum.filter(&(elem(&1, 1) == :carried))
      |> Enum.map(&elem(&1, 0))
  end

  defp drop_carried_items(state) do
    carried = carried_items(state)

    Enum.reduce(carried, state, fn item, state ->
      drop_item(state, item)
    end)
  end

  defp take_item(state, item) do
    state
    |> push_action({:take_item, item})
    |> IOBuffer.push(:input, to_charlist("take #{item}\n"))
  end

  defp drop_item(state, item) do
    state
    |> push_action({:drop_item, item})
    |> IOBuffer.push(:input, to_charlist("drop #{item}\n"))
  end

  defp goto_room(state, destination) do
    %{current_room: current_room, paths: paths} = state

    route = get_path(paths, current_room, destination)

    route
    |> Enum.reduce(state, fn {room, dir}, state ->
      explore_door(room, dir, state)
    end)
  end

  defp explore_door(room, dir, state) do
    # Set the input to go through door
    # Add an action to expect a room
    # Register the current position in :from_pos to register the path
    state
    |> push_action({:take_door, room, dir})
    |> push_action(:explore_room)
    |> IOBuffer.push(:input, Atom.to_charlist(dir) ++ '\n')
  end

  # Breadth first search starting from the destination
  defp get_path(paths, origin, destination) do
    # remove all unknown doors from paths
    paths =
      paths
      |> Enum.map(fn {room, doors_to_rooms} ->
        doors_to_rooms =
          Enum.filter(doors_to_rooms, fn
            {_door, :unknown_room} -> false
            _ -> true
          end)
          |> Map.new()

        {room, doors_to_rooms}
      end)
      |> Map.new()

    # Initialize the current open list with the current room and
    # remove it from paths (paths is used as the map pool)
    {next, paths} = Map.split(paths, [origin])
    open = Map.to_list(next)

    try do
      # IO.puts("find path from #{origin} to #{destination}")
      get_path(paths, open, destination, %{})
      raise "Path not found"
    catch
      {:path_found, ancestry} ->
        reduce_path(ancestry, origin, destination, [])
    end
  end

  defp reduce_path(ancestry, origin, origin, acc),
    do: acc

  defp reduce_path(ancestry, origin, destination, acc) do
    {parent, door} = Map.fetch!(ancestry, destination)
    reduce_path(ancestry, origin, parent, [{parent, door} | acc])
  end

  # for each room in currents, we will check if a door leads to
  # the destination. If yes, we have our path.
  # If not, we will select the paths leading to another room (discard
  # the doors to unknown_room), extract those other rooms from the
  # open list and recurse.
  # Already seen room will not be in the open list so we could not 
  # loop infinitely.

  # open list is empty
  defp get_path(paths, [], destination, ancestry) do
    raise "empty open list, ancestry: #{inspect(ancestry, pretty: true)}"
  end

  defp get_path(paths, [{room, doors_to_rooms} | open], destination, ancestry) do
    # check if we have found our path
    rooms_from_doors =
      Enum.map(doors_to_rooms, fn
        {door, ^destination} ->
          ancestry = Map.put(ancestry, destination, {room, door})
          throw({:path_found, ancestry})

        {door, next_room} ->
          # we just flip the map entries
          {next_room, door}
      end)
      |> Map.new()

    # remove the current rooms from paths 
    {next_open, paths} = Map.split(paths, Map.keys(rooms_from_doors))

    next_open = Map.to_list(next_open)

    # register the moves from the current room in ancestry
    ancestry =
      Enum.reduce(rooms_from_doors, ancestry, fn {next_room, door}, ancestry ->
        # put_new is very inportant or an infinite loop will bite you
        Map.put_new(ancestry, next_room, {room, door})
      end)

    # append next_open so we are breadth first
    open = open ++ next_open
    get_path(paths, open, destination, ancestry)
  end

  def combinations(list, num) do
    do_combinations(list, num)
    |> Enum.map(&{:combination, &1})
  end

  def do_combinations(list, num)
  def do_combinations(_list, 0), do: [[]]
  def do_combinations(list = [], _num), do: list

  def do_combinations([head | tail], num) do
    Enum.map(do_combinations(tail, num - 1), &[head | &1]) ++
      do_combinations(tail, num)
  end

  defp pause() do
    IO.gets("-- Pause ----------------------------------------------")
  end

  defp pause(x) do
    IO.gets("-- Pause ----------------------------------------------")
    x
  end
end

Day25.part1()

System.halt()
