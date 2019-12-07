defmodule Day6 do
  @root "COM"

  def run(str) do
    pairs = parse_orbit_map(str)
    all_counts = count_all_orbits(pairs)
    IO.puts("All Orbits count: #{all_counts}")
    map = Enum.into(pairs, %{})
    path = find_path(map, "YOU", "SAN")
    IO.puts("Shortest path for YOU -> SAN: #{length(path) - 1}")
  end

  defp find_path(map, from, to) do
    # We could remove all common roots and just count the 
    # remaining orbitals, but we want to show the path so we will
    # do something more complicated
    from_root = root_path(map, from, [])
    to_root = root_path(map, to, [])
    {from_short, to_short, common_root} = remove_common_root(from_root, to_root, nil)
    _path = :lists.reverse(from_short) ++ [common_root | to_short]
  end

  defp remove_common_root([h | t1], [h | t2], _),
    do: remove_common_root(t1, t2, h)

  defp remove_common_root(path1, path2, prev_root),
    do: {path1, path2, prev_root}

  defp root_path(_map, @root, path),
    do: path

  defp root_path(map, from, path) do
    next = Map.fetch!(map, from)
    root_path(map, next, [next | path])
  end

  defp count_all_orbits(pairs) do
    reduce_counts(pairs, [], %{@root => 0})
  end

  defp reduce_counts([{k, center} = pair | t], postponed, counts) do
    case Map.fetch(counts, center) do
      {:ok, center_count} ->
        counts = Map.put_new(counts, k, center_count + 1)
        reduce_counts(t, postponed, counts)

      :error ->
        reduce_counts(t, [pair | postponed], counts)
    end
  end

  defp reduce_counts([], [], counts) do
    counts
    |> Enum.reduce(0, fn {k, count}, acc -> acc + count end)
  end

  defp reduce_counts([], postponed, counts) do
    IO.puts("Postponed #{length(postponed)}")
    reduce_counts(postponed, [], counts)
  end

  defp parse_orbit_map(str) do
    str
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&parse_line/1)
  end

  defp parse_line(str) do
    [center, orbital] = String.split(str, ")")
    {orbital, center}
  end
end

"orbits.txt"
|> File.read!()
# """
# COM)B
# B)C
# C)D
# D)E
# E)F
# B)G
# G)H
# D)I
# E)J
# J)K
# K)L
# K)YOU
# I)SAN
# """
|> Day6.run()
|> IO.inspect()

System.halt()
