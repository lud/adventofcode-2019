defmodule Roid do
  defstruct xy: nil, x: nil, y: nil, radials: nil, sim: nil, reach: nil, symb: "#", hex: nil

  def new({x, y} = xy) do
    %Roid{xy: xy, x: x, y: y}
  end

  def set_symb(roid, symb) do
    %Roid{roid | symb: symb}
  end

  def set_radials(roid, radials) do
    %Roid{roid | radials: radials}
  end

  def set_reach_sim(roid, simulated) do
    reach =
      simulated
      |> Enum.filter(fn
        {_, nil} -> false
        _ -> true
      end)
      |> length

    hex = Integer.to_string(reach, 16)

    %Roid{roid | sim: simulated, reach: reach, hex: hex}
  end
end

defmodule Starmap do
  def parse_map(str) do
    str
    |> String.split("\n")
    |> Enum.map(&parse_x/1)
    |> IO.inspect()
    |> Enum.with_index()
    |> add_y
  end

  def has_roid(starmap, {x, y}) do
    Map.has_key?(starmap, {x, y})
  end

  def get(starmap, {x, y} = coords) do
    Map.get(starmap, coords)
  end

  defp parse_x(str_row) do
    str_row
    |> String.graphemes()
    |> Enum.with_index()
    |> collect_x
  end

  defp collect_x(chars, acc \\ [])

  defp collect_x([], acc),
    do: acc

  defp collect_x([{".", _} | chars], acc),
    do: collect_x(chars, acc)

  defp collect_x([{symbol, x} | chars], acc),
    do: collect_x(chars, [{symbol, x} | acc])

  defp add_y(rows_with_y, acc \\ [])

  defp add_y([], acc) do
    acc
    |> :lists.flatten()
    |> Enum.map(&{&1.xy, &1})
  end

  # empty row
  defp add_y([{[], _} | rows], acc),
    do: add_y(rows, acc)

  defp add_y([{symb_xs, y} | rows], acc) do
    roids = symb_xs |> Enum.map(fn {symb, x} -> Roid.new({x, y}) |> Roid.set_symb(symb) end)
    add_y(rows, [roids | acc])
  end

  def max_coords(map) do
    Enum.reduce(map, {0, 0}, fn {{x, y}, _}, {maxx, maxy} ->
      {max(x, maxx), max(y, maxy)}
    end)
  end

  def fmap(starmap, fun) do
    Enum.map(starmap, fn {xy, roid} -> {xy, fun.(roid)} end)
    |> Enum.into(%{})
  end
end

defmodule Day10 do
  @primes [1, 2] ++
            (2..10
             |> Enum.reject(fn n -> Enum.any?(2..(n - 1), &(rem(n, &1) == 0)) end))
  IO.inspect(@primes)

  def run(str) do
    map =
      str
      |> String.trim()
      |> Starmap.parse_map()
      |> IO.inspect()

    {map_max_x, map_max_y} = Starmap.max_coords(map)

    map =
      map
      |> Starmap.fmap(&with_radial_vectors(&1, map_max_x, map_max_y))
      |> IO.inspect()

    map =
      map
      |> Starmap.fmap(&simulate_reach(&1, map, map_max_x, map_max_y))
      |> IO.inspect()

    print_map(map, map_max_x, map_max_y, :symb)
    print_map(map, map_max_x, map_max_y, :hex)

    # Starmap.get(map, {3, 4})

    {_, best} =
      map
      |> Enum.reduce(fn {xy, roid} = cur, {_, best} = acc ->
        if roid.reach > best.reach do
          cur
        else
          acc
        end
      end)

    # print_map_reach(map, best, map_max_x, map_max_y, :symb)
    print_map_reach(map, {0, 0}, map_max_x, map_max_y, :symb)

    IO.puts("best: #{best.x},#{best.y} => #{best.reach}")
    Starmap.get(map, {0, 0})
    #   reach_map
    #   |> Enum.reduce(fn {pos, _vx, count} = roid, {best, max} = acc ->
    #     if count > max do
    #       roid
    #     else
    #       acc
    #     end
    #   end)
  end

  defp print_map(map, map_max_x, map_max_y, field, colors \\ %{}) do
    IO.write("\n")

    for y <- 0..map_max_y do
      for x <- 0..map_max_x do
        val =
          case Starmap.get(map, {x, y}) do
            %Roid{} = roid ->
              char = Map.fetch!(roid, field)
              color = Map.get(colors, roid.xy, :default)
              colorate(char, color)

            nil ->
              "."
          end

        IO.write(val)
      end

      IO.write("\n")
    end

    IO.write("\n")
  end

  defp colorate(str, :default), do: str

  defp colorate(str, :red),
    do: [IO.ANSI.red_background(), str, IO.ANSI.reset()]

  defp colorate(str, :yellow),
    do: [IO.ANSI.yellow_background(), str, IO.ANSI.reset()]

  def print_map_reach(map, {x, y} = xy, map_max_x, map_max_y, field) do
    print_map_reach(map, Starmap.get(map, xy), map_max_x, map_max_y, field)
  end

  def print_map_reach(map, roid, map_max_x, map_max_y, field) do
    colors =
      roid.sim
      |> Enum.map(&elem(&1, 1))
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(&{&1, :red})

    colors =
      [{roid.xy, :yellow} | colors]
      |> Enum.into(%{})

    print_map(map, map_max_x, map_max_y, field, colors)
  end

  # To count reached roids, for each vector we will add it to the
  # coordinates many times, until we find a roid or we reach the edge
  # of the map
  defp simulate_reach(roid, map, map_max_x, map_max_y) do
    simulated =
      roid.radials
      # to discard the current xy roid itself we warp once
      |> Enum.map(&fly_vector(warp(roid.xy, &1), &1, map, map_max_x, map_max_y))

    Roid.set_reach_sim(roid, simulated)
  end

  defp fly_vector({x, y}, vx, map, map_max_x, map_max_y)
       when x < 0 or x > map_max_x or y < 0 or y > map_max_y,
       do: {vx, nil}

  defp fly_vector({x, y} = pos, vx, map, map_max_x, map_max_y) do
    # IO.puts("is #{inspect(pos)} a roid ?")

    if Starmap.has_roid(map, {x, y}) do
      # IO.puts("yes!")
      {vx, {x, y}}
    else
      # IO.puts("no.")
      fly_vector(warp(pos, vx), vx, map, map_max_x, map_max_y)
    end
  end

  defp warp({x, y}, {vx, vy}),
    do: {x + vx, y + vy}

  # for each roid in the map, we calculate the difference  from its
  # point and each edge of the map
  # for example on a map of 0,0:4,4, the point 1,1 has a difference of
  # -1,3:-1,3
  # Then we list all the possible vectors for all directions around
  # the point
  # We only keep vectors where at least one coordinate is a prime 
  # number, because the 2,2 vector is just the 1,1 vector applied 
  # twice. (And 2 is actually prime but 2,2 is not a prime vector).
  # Also vector 0,0 is null so will be discarded
  defp with_radial_vectors(%Roid{x: x, y: y} = roid, map_max_x, map_max_y) do
    max_left = x * -1
    max_right = map_max_x - x
    max_up = y * -1
    max_down = map_max_y - y

    vectors =
      for vx <- max_left..max_right, vy <- max_up..max_down do
        {vx, vy}
      end

    # vectors =
    #   for x <- -1..1, y <- max_up..max_down do
    #     {x, y}
    #   end ++
    #     for x <- max_left..max_right, y <- -1..1 do
    #       {x, y}
    #     end

    vectors =
      vectors
      |> Enum.sort()
      |> Enum.dedup()
      |> IO.inspect(label: "VECTORS BEFORE")
      |> Enum.filter(&keep_vector/1)
      |> IO.inspect(label: "VECTORS")

    Roid.set_radials(roid, vectors)
  end

  def keep_vector({0, 0}), do: false
  def keep_vector({0, y}) when y in [-1, 1], do: true
  def keep_vector({0, _}), do: false
  def keep_vector({x, 0}) when x in [-1, 1], do: true
  def keep_vector({_, 0}), do: false
  def keep_vector({1, 1}), do: true
  def keep_vector({-1, -1}), do: true
  def keep_vector({-1, 1}), do: true
  def keep_vector({1, -1}), do: true
  def keep_vector({x, x}), do: false
  def keep_vector({x, y}) when abs(x) == abs(y), do: false
  # def keep_vector({x, y}) when is_prime(x) and is_prime(y), do: true
  # def keep_vector(_), do: false

  def keep_vector({x, y}) when rem(x, 2) == 0 and rem(y, 2) == 0,
    do: false

  def keep_vector({x, y}),
    do: true

  # def filter_vectors(vects) do
  #   {zeroes, other} =
  #     Enum.split_with(vects, fn
  #       {0, _} -> true
  #       {_, 0} -> true
  #       other -> false
  #     end)

  #   zeroes =
  #     Enum.filter(zeroes, fn
  #       {0, 1} -> true
  #       {0, -1} -> true
  #       {1, 0} -> true
  #       {-1, 0} -> true
  #       other -> false
  #     end)

  #   other = filter_vectors(other, [])

  #   zeroes ++ other
  # end

  # def filter_vectors([], acc),
  #   do: acc

  # def filter_vectors([vec | vects], acc) do
  #   {x, y} = vec
  #   IO.puts("#{x} / #{y}")
  #   ratio = x / y
  #   has_same = Enum.any?(acc, fn {x, y} -> x / y == ratio end)

  #   if has_same do
  #     filter_vectors(vects, acc)
  #   else
  #     filter_vectors(vects, [vec | acc])
  #   end
  # end
end

# """
# .#..#
# """
# """
# .#..#
# .....
# #####
# ....#
# ...##
# """
"""
......#.#.
#..#.#....
..#######.
.#.#.###..
.#..#.....
..#....#.#
#..#....#.
.##.#..###
##...#..#.
.#....####
"""

"""
#.........
...A......
...B..a...
.EDCG....a
..F.c.b...
.....c....
..efd.c.gb
.......c..
....f...c.
...e..d..c
"""
|> Day10.run()
|> IO.inspect()

System.halt()

"""
#.........
...A......
...B..a...
.EDCG....a
..F.c.b...
.....c....
..efd.c.gb
.......c..
....f...c.
...e..d..c
"""
