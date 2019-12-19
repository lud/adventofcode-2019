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

    # ckeys: collected keys
    # mkeys: missing keys
    init_state = %{ckeys: [], mkeys: knames, steps: 0, pos: entrance_xy}

    walk_to_all_keys(grid, [init_state], keys, :infinity, length(knames))
    |> IO.inspect(label: "Best")
  end

  defp walk_to_all_keys(grid, states, keys, best, 0) when is_list(states) do
    states
    |> Enum.reduce(99_999_999_999, &reduce_best/2)
  end

  defp walk_to_all_keys(grid, states, keys, best, count) when is_list(states) do
    IO.puts("count: #{count}")

    states =
      states
      |> Enum.map(fn state -> walk_to_all_keys(grid, state, keys, best) end)
      |> :lists.flatten()
      # keeping the n best
      |> Enum.sort_by(& &1.steps)
      |> Enum.take(1000)

    # {min_steps, max_steps} =
    #   states
    #   |> Enum.reduce({:infinity, -1}, fn
    #     %{steps: steps}, {smin, smax} when steps < smin -> {steps, smax}
    #     %{steps: steps}, {smin, smax} when steps > smax -> {smin, steps}
    #     _, acc -> acc
    #   end)
    #   |> IO.inspect()

    # best_tier = div(max_steps - min_steps, 2) + min_steps

    # states =
    #   states
    #   |> Enum.filter(fn %{steps: steps} -> steps <= best_tier end)

    walk_to_all_keys(grid, states, keys, best, count - 1)
  end

  defp reduce_best(%{steps: steps}, best) when steps < best, do: steps
  defp reduce_best(_, best), do: best

  defp walk_to_all_keys(grid, state, keys, best) do
    %{mkeys: mkeys, ckeys: ckeys, pos: pos, steps: steps} = state

    IO.puts("#{ckeys} -> #{mkeys}")
    # create a new branch for all missing keys. 
    # collected keys (ckeys) are always sorted to help caching paths
    next_states =
      Enum.map(mkeys, fn mk ->
        destination = Map.fetch!(keys, mk)

        case path_length(grid, pos, destination, ckeys) do
          :error ->
            :skip

          add_steps ->
            new_ckeys = insert(ckeys, mk)
            new_mkeys = mkeys -- [mk]
            new_steps = steps + add_steps

            state = %{
              state
              | steps: new_steps,
                ckeys: new_ckeys,
                mkeys: new_mkeys,
                pos: destination
            }

            {mk, state}
        end
      end)
      |> Enum.filter(fn
        :skip ->
          false

        {mk, %{ckeys: ckeys, steps: steps}} = state ->
          # Check if another path got here (same mk position) with better path
          pkey = {:reached, ckeys, mk}

          case Process.get(pkey) do
            best_steps when best_steps <= steps ->
              false

            _ ->
              Process.put(pkey, steps)
              true
          end
      end)
      |> Enum.map(fn {_, state} -> state end)
  end

  defguard is_key(key) when key >= ?a and key <= ?z
  defguard is_door(door) when door >= ?A and door <= ?Z

  defp path_length(grid, from, to, ckeys) do
    computed = Process.get({:registered_paths, {from, to}}, %{})

    existing =
      computed
      |> Enum.filter(fn
        {used_keys, len_or_error} ->
          cond do
            used_keys == ckeys -> true
            used_keys -- ckeys == [] and len_or_error != :error -> true
            true -> false
          end
      end)

    case existing do
      [] ->
        Process.put(:used_keys, [])

        len_or_error =
          GridMap.get_path(grid, from, to, fn
            @wall ->
              false

            @entrance ->
              true

            @empty ->
              true

            key when is_key(key) ->
              true

            door when is_door(door) ->
              key = door_to_key(door)

              if :lists.member(key, ckeys) do
                used_keys = Process.get(:used_keys)
                Process.put(:used_keys, insert(used_keys, key))
              else
                false
              end
          end)
          |> case do
            {:ok, path} -> length(path)
            {:error, _} -> :error
          end

        used_keys = Process.get(:used_keys)
        paths = Process.get({:registered_paths, {from, to}}, %{})
        paths = Map.put(paths, used_keys, len_or_error)
        Process.put({:registered_paths, {from, to}}, paths)
        # IO.puts("#{inspect(from)} -> #{inspect(to)} required keys: #{used_keys}")
        len_or_error

      found ->
        # IO.puts("#{inspect(from)} -> #{inspect(to)} found from cache")
        {_, len_or_error} = Enum.min(found)
        len_or_error
    end
  end

  def insert([v | _] = list, v), do: list
  def insert([c | rest], v) when c < v, do: [c | insert(rest, v)]
  def insert(list, v), do: [v | list]

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

"day18.puzzle"
|> File.read!()
|> Day18.run()
|> IO.inspect()
