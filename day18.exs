defmodule Vault do
  @behaviour GridMap
  def init() do
    %{
      # position of robot
      pos: nil,
      # keys laying on the floor
      keys: %{},
      # keys collected
      ckeys: [],
      doors: %{},
      steps: 0,
      trace: []
    }
  end

  @wall ?#
  @empty ?.
  @entrance ?@

  defguard is_key(key) when key >= ?a and key <= ?z
  defguard is_door(door) when door >= ?A and door <= ?Z

  def missing_keys(%{keys: keys, ckeys: ckeys}) do
    keys
    |> Enum.filter(fn {coords, key} -> not :lists.member(key, ckeys) end)
  end

  def parse_content({_coords, @wall}, state),
    do: {@wall, state}

  def parse_content({_coords, @empty}, state),
    do: {@empty, state}

  def parse_content({coords, key}, state) when is_key(key) do
    state = register_key(state, coords, key)
    {key, state}
  end

  def parse_content({coords, door}, state) when door >= ?A and door <= ?Z do
    state = register_door(state, coords, door)
    {door, state}
  end

  def parse_content({coords, @entrance}, state) do
    {@entrance, %{state | pos: coords}}
  end

  def parse_content({coords, char}, state) do
    raise "unknown content '#{[char]}'"
  end

  defp register_key(state, coords, key) do
    %{keys: fkeys} = state
    %{state | keys: Map.put(fkeys, coords, key)}
  end

  defp register_door(state, coords, door) do
    %{doors: doors} = state
    %{state | doors: Map.put(doors, coords, door)}
  end

  def walkable?({coords, typ}, state) when typ in [@entrance, @empty],
    do: true

  def walkable?({coords, @wall}, state),
    do: false

  def walkable?({coords, key}, state) when is_key(key),
    do: true

  def walkable?({coords, door}, state) when is_door(door) do
    key = door + 32
    has_ckey?(state, key)
  end

  def walkable?({coords, key}, _state),
    do: raise("@todo walkable? unknown '#{[key]}'")

  def walk_over({coords, char}, state) do
    # When walking over a door we check nothing as our pathfinding 
    # knows if the door is walkable
    if is_key(char) do
      maybe_add_key(state, char)
    else
      state
    end
    |> increment_steps()
    |> set_position(coords)
  end

  def walk_over({coords, key}, state),
    do: raise("@todo walk over unknown '#{[key]}'")

  defp set_position(state, pos),
    do: Map.put(state, :pos, pos)

  # def walk_over({coords, content}, state) do
  # end
  defp increment_steps(%{steps: n} = state) do
    # IO.puts("STEP #{n} -> #{n + 1}")
    %{state | steps: n + 1}
  end

  defp maybe_add_key(state, key) do
    if has_ckey?(state, key) do
      state
    else
      # IO.puts("Found a key: #{[key]}")
      %{state | ckeys: [key | state.ckeys]}
    end
  end

  defp has_ckey?(%{ckeys: ckeys}, key) do
    :lists.member(key, ckeys)
  end
end

defmodule Day18 do
  def run(str_map) do
    map = GridMap.parse_map(str_map, Vault)
    # Now for each key that is not collected, we will check if we can
    # go there.
    # 
    # If we can go, we create a new copy of map/state, and make it go
    # there, collecting the target key (and any other on the way) when
    # walking on it, and registering how much steps we made, and order
    # of collected keys.
    #
    # Then we loop, branching at each time. When there is no more key
    # to collect in a map/state branch, it is stopped.
    # 
    # Finally, we flatten all our branches and check the one with the
    # least steps.

    # tree =
    #   map.state
    #   |> Vault.missing_keys()
    #   |> Enum.map(&elem(&1, 1))
    #   |> compute_tree
    #   |> IO.inspect()

    maps =
      walk_to_all_keys(map)
      |> :lists.flatten()
      |> find_least_steps
      |> IO.inspect(label: "Phase 1")
  end

  defp compute_tree(keys) do
    keys
    |> Enum.map(fn key ->
      rest = keys -- [key]
      %{node: key, branches: compute_tree(rest)}
    end)
  end

  defp find_least_steps(maps) do
    maps
    |> Enum.map(fn %GridMap{} = map -> map.state end)
    |> find_least_steps_2
  end

  defp find_least_steps_2([h | t]),
    do: find_least_steps_2(t, h)

  defp find_least_steps_2([%{steps: h_steps} = h | t], %{steps: mini}) when h_steps < mini,
    do: find_least_steps_2(t, h)

  defp find_least_steps_2([%{steps: h_steps} = h | t], %{steps: mini} = best),
    do: find_least_steps_2(t, best)

  defp find_least_steps_2([], state), do: state

  defp walk_to_all_keys(maps) when is_list(maps) do
    IO.puts("Simulating #{length(maps)} states")
    x = for map <- maps, do: walk_to_all_keys(map)
  end

  defp walk_to_all_keys(%GridMap{} = map) do
    %{state: state} = map
    %{pos: pos, steps: steps} = state
    indent = String.duplicate("  ", length(state.trace))

    # Check if this state has already been reached by another
    # simulation. It is possible because we can walk over a key an
    # pick it up when going for another one

    # IO.puts("#{inspect({:steps, :lists.reverse(state.ckeys)})} => #{steps}")

    pkey = {:steps, Enum.sort(state.ckeys)}

    case Process.get(pkey) do
      better when better <= steps ->
        IO.puts("Abandon seen state, better concurrent for #{state.ckeys}")
        []

      _ ->
        Process.put(pkey, steps)

        state
        |> Vault.missing_keys()
        # |> Enum.sort_by(fn {_, k} -> k end)
        # |> IO.inspect()
        |> case do
          [] ->
            IO.puts(
              "#{indent}All keys found #{format_keys(:lists.reverse(state.ckeys))} in #{
                state.steps
              } steps"
            )

            map

          keys ->
            # IO.puts(
            #   "-- Missing #{length(keys)} keys #{format_keys(state.ckeys)} -> #{format_keys(keys)}"
            # )

            keys
            |> Enum.reduce([], fn {coords, key}, maps ->
              # IO.puts("-- Go next key #{format_keys(state.ckeys)} -> #{[key]}")

              map =
                GridMap.update_state(map, fn state ->
                  # @todo remove trace as we append to list
                  %{state | trace: state.trace ++ [key]}
                end)

              case GridMap.walk_path(map, pos, coords) do
                {:ok, new_map} ->
                  # IO.puts("found path, collected #{new_map.state.ckeys}")
                  # IO.inspect(new_map.state.trace, label: "trace")
                  # IO.puts("#{indent}path found, now explore #{inspect(map.state.trace)} -> ?")
                  [walk_to_all_keys(new_map) | maps]

                # maps ++ [new_map]

                {:error, :no_path} ->
                  # IO.puts("#{indent}no path, abandon trace #{inspect(map.state.trace)}")
                  # Process.sleep(1000)
                  maps
              end
            end)

            # |> tap(fn -> Process.sleep(1000) end)
        end
    end
  end

  defp tap(value, fun) when is_function(fun, 1) do
    fun.(value)
    value
  end

  defp tap(value, fun) when is_function(fun, 0) do
    fun.()
    value
  end

  # defp format_keys(keys) when is_map(keys) do
  #   keys
  #   |> Map.values()
  #   |> IO.inspect()
  #   |> format_keys
  # end

  defp format_keys([{{_, _}, _} = h | _] = keys) do
    keys
    |> Enum.map(&elem(&1, 1))
    |> format_keys
  end

  defp format_keys([i | _] = keys) when is_list(keys) and is_integer(i) do
    Enum.intersperse(keys, ?,)
  end

  defp format_keys([]) do
    "no-keys"
  end
end

"""
#################
#i.G..c...e..H.p#
########.########
#j.A..b...f..D.o#
########@########
#k.E..a...g..B.n#
########.########
#l.F..d...h..C.m#
#################
"""

# """
# ########################
# #...............b.C.D.f#
# #.######################
# #.....@.a.B.c.d.A.e.F.g#
# ########################
# """
|> Day18.run()
