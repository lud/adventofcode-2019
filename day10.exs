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
  defstruct vector: nil, directions: nil, distance: nil, ratio: nil, clock: nil

  def new({vector, directions, distance, ratio, clock}) do
    %__MODULE__{
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
    start_map =
      map =
      str
      |> String.trim()
      |> Starmap.parse_map()

    run_map(map)
  end

  defp run_map(start_map) do
    map = start_map
    {map_max_x, map_max_y} = Starmap.max_coords(map)

    map =
      map
      |> Starmap.fmap(&fly_to_all_others(&1, map, map_max_x, map_max_y))
      |> Starmap.fmap(&reduce_fly_paths/1)

    map =
      map
      |> Starmap.fmap(&count_reach/1)

    print_map(map, map_max_x, map_max_y, :symb)
    print_map(map, map_max_x, map_max_y, :sreach)

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

    print_map(start_map, map_max_x, map_max_y, :symb)
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

    {ratio, clockval} =
      case {vector, directions} do
        # 270 degrees === 9h oclock
        # left
        {{x, 0}, {-1, :straight}} ->
          {dx, 270}

        # right
        {{x, 0}, {1, :straight}} ->
          {dx, 90}

        # top
        {{0, y}, {dx, -1}} ->
          {dy, 0}

        # bottom
        {{0, y}, {dx, 1}} ->
          {dy, 180}

        {{x, y}, directions} when x != 0 and y != 0 ->
          # I can't to math in erlang so we will use a simple trick
          clock =
            case {dx, dy} do
              # from 0 to 3 hours
              {1, -1} when x > 0 and y < 0 ->
                # increasing y ..0 makes the clock bakcwards so we
                # subtract its abs value (we add it as it is negative)
                # 100 * x - abs(y)
                # increasing 0..x makes the clock turn
                100 * x + y

              # from 3 to 6 hours
              {1, 1} when x > 0 and y > 0 ->
                # increasing x makes the clock tend to 3
                # increasing y makes the clock tend to 6
                # so we subtract x
                10000 * y - 100 * x

              # from 6 to 9 hours
              {-1, 1} when x < 0 and y > 0 ->
                -1_000_000 * x - 10000 * y

              {-1, -1} when x < 0 and y < 0 ->
                -100_000_000 * x - 1_000_000 * y
            end

          ratio = Float.round(abs(x) / abs(y), 5)
          {ratio, clock}
      end

    FlyPath.new({vector, directions, distance, ratio, clockval})
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

# """
# ...###.#########.####
# .######.###.###.##...
# ####.########.#####.#
# ########.####.##.###.
# ####..#.####.#.#.##..
# #.################.##
# ..######.##.##.#####.
# #.####.#####.###.#.##
# #####.#########.#####
# #####.##..##..#.#####
# ##.######....########
# .#######.#.#########.
# .#.##.#.#.#.##.###.##
# ######...####.#.#.###
# ###############.#.###
# #.#####.##..###.##.#.
# ##..##..###.#.#######
# #..#..########.#.##..
# #.#.######.##.##...##
# .#.##.#####.#..#####.
# #.#.##########..#.##.
# """
"""
.#....#####...#..
##...##.#####..##
##...#...#.#####.
..#.....X...###..
..#.#.....#....##
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
