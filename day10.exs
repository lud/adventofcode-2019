defmodule Roid do
  defstruct xy: nil, x: nil, y: nil, paths: nil, reach: 0, symb: "#", hex: 0

  def new({x, y} = xy) do
    %Roid{xy: xy, x: x, y: y}
  end

  def set_symb(roid, symb) do
    %Roid{roid | symb: symb}
  end

  def set_reach(roid, reach) do
    hex = Integer.to_string(reach, 16)
    %Roid{roid | reach: reach, hex: hex}
  end

  def set_paths(roid, paths) do
    %Roid{roid | paths: paths}
  end
end

defmodule FlyPath do
  defstruct vector: nil, directions: nil, distance: nil, ratio: nil

  def new({vector, directions, distance, ratio}) do
    %__MODULE__{vector: vector, directions: directions, distance: distance, ratio: ratio}
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
    |> Map.new()
  end

  def has_roid(starmap, {x, y}) do
    Map.has_key?(starmap, {x, y})
  end

  def get(starmap, {x, y} = coords) do
    Map.get(starmap, coords)
  end

  def fetch!(starmap, {x, y} = coords) do
    Map.fetch!(starmap, coords)
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
      |> Starmap.fmap(&fly_to_all_others(&1, map))
      |> IO.inspect()
      |> Starmap.fmap(&reduce_fly_paths/1)

    map =
      map
      |> Starmap.fmap(&count_reach/1)
      |> IO.inspect()

    # map =
    #   map
    #   |> Starmap.fmap(&simulate_reach(&1, map, map_max_x, map_max_y))
    #   |> IO.inspect()

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

    print_map_reach(map, best, map_max_x, map_max_y, :symb)

    IO.puts("best: #{best.x},#{best.y} => #{best.reach}")
    # Starmap.get(map, {0, 0})
    #   reach_map
    #   |> Enum.reduce(fn {pos, _vx, count} = roid, {best, max} = acc ->
    #     if count > max do
    #       roid
    #     else
    #       acc
    #     end
    #   end)
  end

  defp count_reach(roid) do
    Roid.set_reach(roid, Map.size(roid.paths))
  end

  defp reduce_fly_paths(%Roid{} = roid),
    do: Map.update!(roid, :paths, &reduce_fly_paths/1)

  # For each roid, we will see if there is another roid in the same
  # direction (same ratio) but with a closer distance, and reject it
  defp reduce_fly_paths(paths) do
    paths
    |> Enum.reject(fn {xy, %FlyPath{} = fp} ->
      Enum.any?(paths, fn
        {^xy, ^fp} ->
          false

        {_, fp2} ->
          if fp.directions == fp2.directions and fp.ratio == fp2.ratio and
               fp.distance > fp2.distance do
            IO.puts("rejected !")
            true
          else
            false
          end
      end)
    end)
    |> Enum.into(%{})
  end

  defp fly_to_all_others(roid, map) do
    paths =
      map
      |> Starmap.fmap(fn
        ^roid -> nil
        other -> compute_fly_path(roid, other)
      end)
      |> Enum.filter(fn
        {_, nil} -> false
        _ -> true
      end)
      |> Enum.into(%{})

    Roid.set_paths(roid, paths)
  end

  defp compute_fly_path(roid, other) do
    {x, y} = roid.xy
    {x2, y2} = other.xy
    vector = {vx, vy} = {x2 - x, y2 - y}
    directions = get_directions(vector)
    distance = abs(vx) + abs(vy)

    ratio =
      case {vector, directions} do
        {{x, 0}, {dx, dy}} -> dx
        {{0, y}, {dx, dy}} -> dy
        {{x, y}, _} -> Float.round(abs(x) / abs(y), 5)
      end

    FlyPath.new({vector, directions, distance, ratio})
  end

  defp get_directions({x, y}),
    do: {get_direction(x), get_direction(y)}

  defp get_direction(0),
    do: :straight

  defp get_direction(x) when x > 0,
    do: 1

  defp get_direction(x) when x < 0,
    do: -1

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
    print_map_reach(map, Starmap.fetch!(map, xy), map_max_x, map_max_y, field)
  end

  def print_map_reach(map, roid, map_max_x, map_max_y, field) do
    colors =
      roid.paths
      |> Enum.map(&elem(&1, 0))
      |> Enum.map(&{&1, :red})

    colors =
      [{roid.xy, :yellow} | colors]
      |> Enum.into(%{})

    print_map(map, map_max_x, map_max_y, field, colors)
  end
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
.#..#..###
####.###.#
....###.#.
..###.##.#
##.##.#.#.
....###..#
..#.#..#.#
#..#.#.###
.##...##.#
.....#.#..
"""

"""
...###.#########.####
.######.###.###.##...
####.########.#####.#
########.####.##.###.
####..#.####.#.#.##..
#.################.##
..######.##.##.#####.
#.####.#####.###.#.##
#####.#########.#####
#####.##..##..#.#####
##.######....########
.#######.#.#########.
.#.##.#.#.#.##.###.##
######...####.#.#.###
###############.#.###
#.#####.##..###.##.#.
##..##..###.#.#######
#..#..########.#.##..
#.#.######.##.##...##
.#.##.#####.#..#####.
#.#.##########..#.##.
"""
|> Day10.run()
|> IO.inspect()

System.halt()

# """
# #.........
# ...A......
# ...B..a...
# .EDCG....a
# ..F.c.b...
# .....c....
# ..efd.c.gb
# .......c..
# ....f...c.
# ...e..d..c
# """
