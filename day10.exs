defmodule Roid do
  defstruct xy: nil, x: nil, y: nil, paths: nil, reach: 0, symb: "#", sreach: 0

  def new({x, y} = xy) do
    %Roid{xy: xy, x: x, y: y}
  end

  def set_symb(roid, symb) do
    %Roid{roid | symb: symb}
  end

  def set_reach(roid, reach) do
    sreach = Integer.to_string(reach, 32)
    %Roid{roid | reach: reach, sreach: sreach}
  end

  def set_paths(roid, paths) do
    %Roid{roid | paths: paths}
  end
end

defmodule FlyPath do
  defstruct dest: nil, vector: nil, directions: nil, distance: nil, ratio: nil, clock: nil

  def new({dest, vector, directions, distance, ratio, clock}) do
    %__MODULE__{
      dest: dest,
      vector: vector,
      directions: directions,
      distance: distance,
      ratio: ratio,
      clock: clock
    }
  end
end

defmodule Starmap do
  def parse_map(str) do
    str
    |> String.split("\n")
    |> Enum.map(&parse_x/1)
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

  def size(starmap) do
    Map.size(starmap)
  end

  def vaporize(starmap, {x, y} = key) do
    true = Map.has_key?(starmap, key)
    Map.delete(starmap, key)
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

  def run(str) do
    raw_map =
      map =
      str
      |> String.trim()
      |> Starmap.parse_map()

    run_map(map)
  end

  defp run_map(raw_map, vap_count \\ 0, vap_source \\ nil) do
    map = raw_map
    {map_max_x, map_max_y} = Starmap.max_coords(map)

    map =
      map
      |> Starmap.fmap(&fly_to_all_others(&1, map, map_max_x, map_max_y))
      |> Starmap.fmap(&reduce_fly_paths/1)

    map =
      map
      |> Starmap.fmap(&count_reach/1)

    # print_map(map, map_max_x, map_max_y, :sreach)

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

    vaporize_center =
      case vap_source do
        nil -> best.xy
        {_, _} = other -> other
      end

    print_map_reach(map, vaporize_center, map_max_x, map_max_y, :symb)

    # IO.puts("best: #{best.x},#{best.y} => #{best.reach}")

    to_vaporize =
      Starmap.get(map, vaporize_center).paths
      |> Enum.sort_by(fn {xy, roid} -> roid.clock end)
      |> Enum.map(&elem(&1, 1))

    map_size = Starmap.size(raw_map)
    raw_map = vaporize_roids(raw_map, to_vaporize, vap_count)
    new_size = Starmap.size(raw_map)

    if new_size > 1 do
      run_map(raw_map, vap_count + (map_size - new_size), vaporize_center)
    else
      receive do
        {:vap_200, {x, y}} ->
          IO.puts("Vaporized 200th: #{100 * x + y}")
      end

      map
    end
  end

  defp vaporize_roids(map, [], _),
    do: map

  defp vaporize_roids(map, [path | paths], count) do
    map = Starmap.vaporize(map, path.dest)
    count = count + 1

    if count == 200 do
      send(self(), {:vap_200, path.dest})
      IO.puts("Vaporized #{count}: #{inspect(path.dest)}")
    end

    vaporize_roids(map, paths, count)
  end

  defp count_reach(roid) do
    Roid.set_reach(roid, Map.size(roid.paths))
  end

  defp reduce_fly_paths(%Roid{} = roid) do
    Map.update!(roid, :paths, &reduce_fly_paths/1)
  end

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
            true
          else
            false
          end
      end)
    end)
    |> Enum.into(%{})
  end

  defp fly_to_all_others(roid, map, map_max_x, map_max_y) do
    paths =
      map
      |> Starmap.fmap(fn
        ^roid -> nil
        other -> compute_fly_path(roid, other, map_max_x, map_max_y)
      end)
      |> Enum.filter(fn
        {_, nil} -> false
        _ -> true
      end)
      |> Enum.into(%{})

    Roid.set_paths(roid, paths)
  end

  defp compute_fly_path(roid, other, map_max_x, map_max_y) do
    {x, y} = roid.xy
    {x2, y2} = other.xy
    vector = {vx, vy} = {x2 - x, y2 - y}
    directions = get_directions(vector)
    distance = abs(vx) + abs(vy)

    # The map is big so we will multiply our degrees by a large number
    coef = 10000

    {ratio, clockval} =
      case {vector, directions} do
        # 270 degrees === 9h oclock
        # left
        {{vx, 0}, {-1, :straight}} ->
          {-1, 270 * coef}

        # right
        {{vx, 0}, {1, :straight}} ->
          {1, 90 * coef}

        # top
        {{0, vy}, {:straight, -1}} ->
          {-1, 0 * coef}

        # bottom
        {{0, vy}, {:straight, 1}} ->
          {1, 180 * coef}

        {{vx, vy}, directions} when vx != 0 and vy != 0 ->
          clock =
            case {abs(vx), abs(vy), directions} do
              {avx, avy, {1, -1}} when avx < avy -> 45 * coef - avy / avx
              {sam, sam, {1, -1}} -> 45 * coef
              {avx, avy, {1, -1}} when avx > avy -> 45 * coef + avx / avy
              {avx, avy, {1, 1}} when avx > avy -> 135 * coef - avx / avy
              {sam, sam, {1, 1}} -> 135 * coef
              {avx, avy, {1, 1}} when avx < avy -> 135 * coef + avy / avx
              {avx, avy, {-1, 1}} when avx < avy -> 225 * coef - avy / avx
              {sam, sam, {-1, 1}} -> 225 * coef
              {avx, avy, {-1, 1}} when avx > avy -> 225 * coef + avx / avy
              {avx, avy, {-1, -1}} when avx > avy -> 315 * coef - avx / avy
              {sam, sam, {-1, -1}} -> 315 * coef
              {avx, avy, {-1, -1}} when avx < avy -> 315 * coef + avy / avx
            end

          # I can't to math in erlang so we will use a simple trick
          ratio = Float.round(abs(vx) / abs(vy), 5)
          {ratio, clock}
      end

    FlyPath.new({other.xy, vector, directions, distance, ratio, clockval})
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
# """
# ......#.#.
# #..#.#....
# ..#######.
# .#.#.###..
# .#..#.....
# ..#....#.#
# #..#....#.
# .##.#..###
# ##...#..#.
# .#....####
# """

# """
# .#..#..###
# ####.###.#
# ....###.#.
# ..###.##.#
# ##.##.#.#.
# ....###..#
# ..#.#..#.#
# #..#.#.###
# .##...##.#
# .....#.#..
# """

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
# """
# .#....#####...#..
# ##...##.#####..##
# ##...#...#.#####.
# ..#.....X...###..
# ..#.#.....#....##
# """
|> Day10.run()

# |> IO.inspect()

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
