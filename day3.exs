defmodule Day3 do
  defstruct wires: [], central: {0, 0}, offset: {0, 0}

  def create_data() do
    %__MODULE__{}
  end

  def add_wire(this, path_str) do
    moves =
      path_str
      |> String.split(",")
      |> Enum.map(&parse_move/1)

    {offset_x, offset_y} = this.offset

    wire =
      sim_moves({offset_x, offset_y, :start}, moves)
      |> IO.inspect()

    this =
      Map.update!(this, :wires, fn l -> [wire | l] end)
      |> offset_all_positions()

    {min_x, min_y} = get_min_coords(this)
    IO.inspect({min_x, min_y}, label: "Min coords")
    this
  end

  def parse_move(<<letter::utf8, rest::binary>>) do
    {parse_letter(letter), String.to_integer(rest)}
  end

  def parse_letter(?U), do: :up
  def parse_letter(?R), do: :right
  def parse_letter(?L), do: :left
  def parse_letter(?D), do: :down

  def sim_moves(position, moves, positions \\ [])

  def sim_moves(position, [], positions) do
    :lists.reverse(positions)
  end

  def sim_moves(position, [{direction, amount} = move | moves], positions) when amount > 0 do
    new_pos = do_move(position, {direction, 1})
    sim_moves(new_pos, [{direction, amount - 1} | moves], [new_pos | positions])
  end

  def sim_moves(position, [{direction, 0} | moves], positions) do
    sim_moves(position, moves, positions)
  end

  def do_move({x, y, _}, {:left, offset}), do: {x - offset, y, :left}
  def do_move({x, y, _}, {:right, offset}), do: {x + offset, y, :right}
  def do_move({x, y, _}, {:up, offset}), do: {x, y - offset, :up}
  def do_move({x, y, _}, {:down, offset}), do: {x, y + offset, :down}

  def create_grid(%{wires: wires, central: central} = this) do
    {max_x, max_y} = get_max_coords(wires)
    IO.inspect({max_x, max_y}, label: "Max coords")

    empty_grid = create_empty_grid(max_x, max_y)

    grid = add_grid_central(empty_grid, central)
    IO.puts("Add wires to grid")

    grid =
      wires
      |> Enum.reduce(grid, fn wire, grid ->
        wire_to_grid(wire, grid)
      end)
      |> IO.inspect(label: :empty_grid)

    grid
  end

  def add_grid_central(grid, {x, y}) do
    change_tile(grid, {x, y}, :central)
  end

  def wire_to_grid([{x, y, move}, {_, _, move} = next | posses], grid) do
    IO.puts("wire next")
    grid = change_tile(grid, {x, y}, move)

    wire_to_grid([next | posses], grid)
  end

  def wire_to_grid([{x, y, move}, {_, _, change_move} = next | posses], grid) do
    IO.puts("wire change")
    grid = change_tile(grid, {x, y}, :turn)

    wire_to_grid([next | posses], grid)
  end

  def wire_to_grid([{x, y, move} | []], grid) do
    IO.puts("wire last")
    grid = change_tile(grid, {x, y}, move)

    grid
  end

  def change_tile(grid, {x, y}, value) do
    IO.puts("change tile")

    update_in(grid.tiles[{x, y}], fn tile ->
      merge_tile(tile, value)
    end)
  end

  defguard is_conduit(tile) when tile in ~w(up down left right)a

  def merge_tile(:dot, any),
    do: any

  def merge_tile(current, add) when is_conduit(current) and is_conduit(add),
    do: :cross

  def create_empty_grid(max_x, max_y) do
    tiles =
      for x <- 0..max_x, y <- 0..max_y do
        {{x, y}, :dot}
      end
      |> Enum.into(%{})

    %{tiles: tiles, max_x: max_x, max_y: max_y}
  end

  def draw_grid(%{tiles: tiles, max_x: max_x, max_y: max_y} = grid) do
    for y <- 0..max_y do
      for x <- 0..max_x do
        char = tile_to_char(tiles[{x, y}])
        IO.write(char)
      end

      IO.write("\n")
    end

    grid
  end

  def tile_to_char(:central), do: "O"
  def tile_to_char(:dot), do: "."
  def tile_to_char(:left), do: "-"
  def tile_to_char(:right), do: "-"
  def tile_to_char(:up), do: "|"
  def tile_to_char(:down), do: "|"
  def tile_to_char(:turn), do: "+"
  def tile_to_char(:cross), do: "X"

  def offset_all_positions(this) do
    {min_x, min_y} = get_min_coords(this)
    IO.inspect({min_x, min_y}, label: "Min coords")

    this
    |> Map.update!(:wires, fn wires ->
      wires
      |> Enum.map(fn wire ->
        wire
        |> Enum.map(fn {x, y, move} -> {x - min_x, y - min_y, move} end)
      end)
    end)
    |> Map.update!(:central, fn {x, y} -> {x - min_x, y - min_y} end)
    |> Map.update!(:offset, fn {x, y} -> {x - min_x, y - min_y} end)
  end

  def get_max_coords([h | t]) do
    get_max_coords(get_max_coords(h), get_max_coords(t))
  end

  def get_max_coords([]), do: {0, 0}

  def get_max_coords({x, y, _}),
    do: get_max_coords({x, y})

  def get_max_coords({x, y}),
    do: {x, y}

  def get_max_coords({x, y}, {a, b}) do
    {max(x, a), max(y, b)}
  end

  def get_min_coords(%{wires: wires}),
    do: get_min_coords(wires)

  def get_min_coords([h | t]) do
    get_min_coords(get_min_coords(h), get_min_coords(t))
  end

  def get_min_coords([]), do: {0, 0}

  def get_min_coords({x, y, _}),
    do: get_min_coords({x, y})

  def get_min_coords({x, y}),
    do: {x, y}

  def get_min_coords({x, y}, {a, b}) do
    {min(x, a), min(y, b)}
  end

  def manhattan_distance({a, b}, {x, y}) do
    abs(abs(a) - abs(x)) + abs(abs(b) - abs(y))
  end

  # def find_crosses(wire_a, wire_b)

  # def find_crosses([{x, y, _} | wire_a], wire_b) do
  #   IO.puts("look crosses")

  #   [
  #     find_crosses2({x, y}, wire_b),
  #     find_crosses(wire_a, wire_b)
  #   ]
  # end

  # def find_crosses2({x, y}, [{x, y, _} | wire_b]) do
  #   IO.puts("cross found")
  #   {x, y}
  # end

  # def find_crosses2({x, y}, [other | wire_b]) do
  #   find_crosses2({x, y}, wire_b)
  # end

  # def find_crosses2({x, y}, []) do
  #   []
  # end

  def find_crosses(wire_a, wire_b) do
    wire_a =
      wire_a
      |> Enum.map(fn {x, y, _} -> {x, y} end)
      |> Enum.sort()

    wire_b =
      wire_b
      |> Enum.map(fn {x, y, _} -> {x, y} end)
      |> Enum.sort()

    find_crosses_sorted(wire_a, wire_b)
  end

  def find_crosses_sorted([pos_a | wire_a], [pos_b | wire_b]) when pos_a > pos_b,
    do: find_crosses_sorted([pos_a | wire_a], wire_b)

  def find_crosses_sorted([pos_a | wire_a], [pos_b | wire_b]) when pos_a < pos_b,
    do: find_crosses_sorted(wire_a, [pos_b | wire_b])

  def find_crosses_sorted([pos_a | wire_a], [pos_b | wire_b]) when pos_a == pos_b,
    do: [pos_a | find_crosses_sorted(wire_a, wire_b)]

  def find_crosses_sorted([], _),
    do: []

  def find_crosses_sorted(_, []),
    do: []

  def wire_distance(cross, wire, dist \\ 1)

  def wire_distance({x, y}, [{x, y, _} | wire], dist),
    do: dist

  def wire_distance(cross, [_ | wire], dist),
    do: wire_distance(cross, wire, dist + 1)

  def run(wires_paths) do
    state =
      wires_paths
      |> Enum.reduce(create_data(), fn path, this ->
        add_wire(this, path)
      end)

    [wire_a, wire_b] = state.wires
    crosses = find_crosses(wire_a, wire_b)

    %{central: central} = state

    min_manhattan =
      crosses
      |> Enum.map(fn {x, y} -> manhattan_distance(central, {x, y}) end)
      |> Enum.reduce(&min(&1, &2))
      |> IO.inspect(label: "Minimum Manhattan")

    crosses
    |> Enum.map(fn {x, y} -> {wire_distance({x, y}, wire_a), wire_distance({x, y}, wire_b)} end)
    |> IO.inspect()
    |> Enum.map(fn {wire_a_dist, wire_b_dist} -> wire_a_dist + wire_b_dist end)
    |> Enum.reduce(&min(&1, &2))
    |> IO.inspect(label: "Minimum wire distance")

    # grid =
    #   state
    #   |> create_grid()

    # |> draw_grid()

    # %{central: central} = state

    # grid.tiles
    # |> Enum.filter(fn
    #   {_, :cross} -> true
    #   _ -> false
    # end)
    # |> Enum.map(fn {{x, y}, _} -> manhattan_distance(central, {x, y}) end)
    # |> Enum.reduce(&min(&1, &2))
  end
end

# Day3.run(["R8,U5,L5,D3", "U7,R6,D4,L4"])
# Day3.run([
#   "R75,D30,R83,U83,L12,D49,R71,U7,L72",
#   "U62,R66,U55,R34,D71,R55,D58,R83"
# ])
# Day3.run([
#   "R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51",
#   "U98,R91,D20,R16,D67,R40,U7,R15,U6,R7"
# ])
Day3.run([
  "R1000,U564,L752,D449,R783,D938,L106,U130,R452,U462,R861,U654,L532,D485,R761,U336,L648,U671,L618,U429,R122,D183,L395,U662,R900,U644,L168,D778,L268,U896,L691,D852,L987,U462,R346,U103,R688,U926,R374,D543,R688,D682,R992,D140,L379,D245,L423,D504,R957,U937,L67,D560,L962,U275,R688,D617,L778,U581,R672,D402,R3,U251,R593,U897,L866,U189,L8,D5,R761,U546,R594,D880,L318,U410,L325,U564,L889,U688,L472,D146,R317,D314,L229,U259,R449,D630,L431,U4,R328,D727,R298,D558,R81,D508,L160,U113,L994,U263,L193,D631,R881,D608,L924,U447,R231,U885,L157,D739,R656,D121,R704,U437,L710,D207,R150,U406,R816,U683,R496,D715,L899,U757,L579,D684,L85,D354,R198,D411,R818,U772,L910,U493,R38,D130,L955,U741,R744,D224,L485,U201,L903,D904,R748,U288,R34,U673,R503,D931,L190,U547,L83,D341,R459,U114,L758,U220,L506,U444,L472,D941,L68,D910,R415,U668,L957,U709,R817,U116,R699,D424,R548,D285,R347,U396,R791,U62,L785,D360,L628,U415,L568,D429,R154,D840,L865,U181,L106,D564,L452,U156,L967,D421,R41,U500,L316,D747,R585,D858,L809,U402,L484,U752,R319,D563,R273,U84,R53,U874,L849,U90,R194,D969,R907,D625,L298,D984,R744,U172,R537,D177,L14,D921,L156,U133,R429,D787,R688,U894,L154,U192,R663,D225,L781,U426,R623,D60,L723,D995,R814,D195,L951,D594,R994,D543,L893,U781,R899,U85,R270,U303,R256,U977,R894,U948,R270,D301,L874,D388,R290,U986,L660,D741,L25,U381,R814,D150,R578,D529,R550,D176,R221,D653,R529,U83,R351,D462,R492,U338,R611,D5,L137,D547,R305,U356,R83,D880,R522,U681,R353,D54,R910,U774,L462,U48,L511,U750,R98,U455,R585,D579,L594",
  "L1003,U936,R846,U549,L824,D684,R944,U902,R177,U875,L425,U631,L301,U515,L790,D233,R49,U408,L184,D103,R693,D307,L557,D771,L482,D502,R759,D390,L378,U982,L430,U337,L970,U400,R829,U212,L92,D670,R741,D566,L797,U477,L377,U837,R19,U849,L21,D870,L182,U414,L586,U768,L637,U135,R997,U405,L331,D256,L22,D46,L504,D660,L757,U676,L360,D499,R180,D723,L236,U78,R218,U523,L71,D60,L485,U503,L352,D969,R747,U831,L285,D859,L245,D517,L140,U463,L895,U284,L546,U342,R349,D438,R816,U21,L188,U482,L687,D903,L234,U15,L758,D294,R789,D444,L498,D436,L240,D956,L666,U686,R978,D827,R919,U108,R975,D35,R475,U59,L374,U24,L26,D497,R454,D388,R180,D561,R80,D433,R439,D818,R962,D912,R247,U972,R948,D807,R867,D946,R725,U395,R706,U187,L17,U332,L862,D660,L70,U608,R223,D506,R592,U357,R520,D149,L572,D800,L570,D358,R648,U174,R520,U153,L807,U92,R840,U560,L938,D599,R972,D539,R385,D495,L26,D894,L907,D103,L494,U51,L803,D620,L68,D226,R947,U210,R864,D755,L681,D520,L867,D577,R378,D741,L91,D294,L289,D531,L301,U638,L496,U83,L278,D327,R351,D697,L593,U331,R91,D967,R419,D327,R78,U304,R462,D2,L656,D700,L27,D29,L598,U741,L349,D957,R161,U688,R326,D798,L263,U45,L883,U982,R116,D835,L878,U253,L232,D732,R639,D408,R997,D867,R726,D258,L65,D600,L315,U783,L761,U606,R67,D949,L475,U542,L231,U279,L950,U649,L670,D870,L264,U958,R748,D365,R252,D129,R754,U27,R571,D690,L671,U143,L750,U303,L412,U24,L443,D550,R826,U699,L558,U543,L881,D204,R248,D192,R813,U316,L76,D78,R523,U716,L422,D793,R684,D175,L347,D466,L219,D140,L803,U433,R96"
])
|> IO.inspect(label: "Response")

System.halt()
