defmodule PathFinder do
  @behaviour GridMap
end

defmodule Day18 do
  @wall ?#
  @empty ?.
  @entrance ?@

  def run(puzzle) do
    grid = GridMap.parse_map(puzzle)
    keys = GridMap.reduce(grid, %{}, &read_keys/2)

    {entrance_xy, @entrance} =
      GridMap.find(grid, fn
        {_, @entrance} -> true
        _ -> false
      end)

    knames = Map.keys(keys)

    max_distance =
      keys
      |> Enum.reduce(0, fn {_, coords}, max_d ->
        {:ok, path} = get_free_path(grid, entrance_xy, coords)
        max(length(path), max_d)
      end)

    # ckeys: collected keys
    # mkeys: missing keys
    init_state = %{ckeys: [], mkeys: knames, steps: 0, pos: entrance_xy}
    walk_to_all_keys(grid, init_state, keys, :infinity, max_distance)
  end

  defp walk_to_all_keys(grid, %{mkeys: [], steps: steps} = state, keys, best, _) do
    min(steps, best)
  end

  @dist_ratio 0.8

  defp walk_to_all_keys(grid, state, keys, best, max_distance) do
    %{mkeys: mkeys, ckeys: ckeys, pos: pos, steps: steps} = state

    # Check if it is a dumb path
    cklen = length(ckeys)

    distance_per_key =
      if cklen > 0 do
        trunc(steps / cklen)
      else
        0
      end

    if cklen > 0 and steps > max_distance * cklen * @dist_ratio do
      IO.puts("skip #{ckeys}")
      best
    else
      IO.puts("#{ckeys} -> #{mkeys}")
      # create a new branch for all missing keys. 
      # collected keys (ckeys) are always sorted to help caching paths
      Enum.reduce(mkeys, best, fn mk, best ->
        destination = Map.fetch!(keys, mk)

        case path_length(grid, pos, destination, ckeys) do
          :error ->
            IO.puts("Path failed")
            best

          add_steps ->
            new_ckeys = Enum.sort([mk | ckeys])
            new_mkeys = mkeys -- [mk]
            new_steps = steps + add_steps

            state = %{
              state
              | steps: new_steps,
                ckeys: new_ckeys,
                mkeys: new_mkeys,
                pos: destination
            }

            walk_to_all_keys(grid, state, keys, best, max_distance)
        end
      end)
    end
  end

  defp path_length(grid, from, to, ckeys) do
    # use process cache
    pkey = {from, to, ckeys}

    case Process.get(pkey) do
      nil ->
        IO.puts("calc path")

        value =
          case get_path(grid, from, to, ckeys) do
            {:ok, path} -> length(path)
            {:error, :no_path} -> :error
          end

        Process.put(pkey, value)
        value

      value ->
        value
    end
  end

  defguard is_key(key) when key >= ?a and key <= ?z
  defguard is_door(door) when door >= ?A and door <= ?Z

  defp get_path(grid, from, to, ckeys) do
    GridMap.get_path(grid, from, to, fn
      @wall -> false
      @entrance -> true
      @empty -> true
      key when is_key(key) -> true
      door when is_door(door) -> :lists.member(door_to_key(door), ckeys)
    end)
  end

  defp get_free_path(grid, from, to) do
    GridMap.get_path(grid, from, to, fn
      @wall -> false
      _ -> true
    end)
  end

  defp door_to_key(door),
    do: door + 32

  defp read_keys({coords, key}, keys) when is_key(key),
    do: Map.put(keys, key, coords)

  defp read_keys(_, keys),
    do: keys
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

# """
# ########################
# #@..............ac.GI.b#
# ###d#e#f################
# ###A#B#C################
# ###g#h#i################
# ########################
# """

# "day18.puzzle"
# |> File.read!()
|> Day18.run()
|> IO.inspect()
