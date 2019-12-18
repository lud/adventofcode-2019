defmodule GridMap do
  @type coords :: {x :: integer, y :: integer}

  @callback init() :: sate :: any

  @callback walkable?({coords, content :: any}, state :: any) :: bool

  @callback walk_over({coords, content :: any}, state :: any) :: state :: any

  @callback parse_content({coords, integer}, state :: any) :: {content :: any, state :: any}

  defstruct grid: %{}, mod: nil, state: nil, max_xy: nil, min_xy: {0, 0}

  @start_y 0
  @start_x 0

  def parse_map(str, mod) do
    this = %__MODULE__{mod: mod, state: mod.init()}

    this =
      str
      |> String.trim()
      |> to_charlist
      |> parse_chars(this, @start_x, @start_y)
  end

  defp parse_chars([?\n | chars], this, x, y),
    do: parse_chars(chars, this, @start_x, y + 1)

  defp parse_chars([char | chars], this, x, y) do
    %{state: state, mod: mod, grid: grid} = this
    coords = {x, y}
    {content, state} = mod.parse_content({coords, char}, state)
    grid = Map.put(grid, coords, content)
    this = %{this | state: state, grid: grid}
    parse_chars(chars, this, x + 1, y)
  end

  defp parse_chars([], this, x, y) do
    %{this | max_xy: {x, y}}
  end

  defp check_walkable(%{mod: mod, grid: grid, state: state}, coords) do
    case Map.fetch(grid, coords) do
      :error -> false
      {:ok, content} -> mod.walkable?({coords, content}, state)
    end
  end

  defp do_walk_path(coords, %{mod: mod, grid: grid, state: state} = map) do
    content = Map.fetch!(grid, coords)
    state = mod.walk_over({coords, content}, state)
    %{map | state: state}
  end

  # A* Algorithm
  #
  # - h = heuristic
  # - c = move cost from root
  require Record
  # A* node
  Record.defrecord(:anode, coords: nil, parent_xy: nil, h: nil, c: nil)

  def walk_path(map, from, from),
    do: {:ok, map}

  def walk_path(map, from, to) do
    # init the root node
    case astar(map, from, to) do
      {:ok, path} ->
        {:ok, Enum.reduce(path, map, &do_walk_path/2)}

      other ->
        other
    end
  end

  defp astar(map, from, to) do
    # IO.puts("wal from #{inspect(from)} to #{inspect(to)}")
    parent_xy = :root
    root = anode(parent_xy: parent_xy, coords: from, h: 0, c: 0)
    open = [root]
    closed = %{}

    try do
      astar(map, to, open, closed)
    catch
      {:reached, path} -> {:ok, path}
    end
  end

  defp astar(_, _, [] = open, _),
    do: {:error, :no_path}

  defp astar(map, to, open0, closed) do
    [best | open1] = open0
    # IO.inspect(best, label: "Best")
    neighbour_cost = 1 + anode(best, :c)
    best_xy = anode(best, :coords)

    open2 =
      best
      |> anode(:coords)
      |> cardinal_neighbours()
      |> Enum.filter(fn coords -> check_walkable(map, coords) end)
      # we throw if we found our destination. We filter before in case
      # we try to get a path to a non-walkable node
      |> Enum.map(fn
        ^to ->
          path = finalize_path(best, closed, [to])
          throw({:reached, path})

        coords ->
          coords
      end)
      |> Enum.filter(fn coords ->
        cond do
          Map.has_key?(closed, coords) -> false
          open_has_lower_cost?(open1, coords, neighbour_cost) -> false
          true -> true
        end
      end)
      |> Enum.reduce(open1, fn coords, open ->
        distance = manhattan(coords, to)
        h = neighbour_cost + distance
        node = anode(parent_xy: best_xy, c: neighbour_cost, h: h, coords: coords)
        insert_node(open, node)
      end)

    closed = Map.put(closed, best_xy, best)
    astar(map, to, open2, closed)
  end

  # Insert a node on the open list. Objects are inserted in heuristic order

  def insert_node([anode(h: cur_h) = cur | open], anode(h: h) = n) when cur_h < h,
    do: [cur | insert_node(open, n)]

  def insert_node(open, n),
    # we have a bigger heuristic now so we insert in the list
    do: [n | open]

  # Check if the open list contains a node with same coordinates but a lower cost

  defp open_has_lower_cost?([], _, _),
    do: false

  defp open_has_lower_cost?([anode(c: cur_cost, coords: coords) | rest], coords, cost),
    do: cur_cost < coords

  defp open_has_lower_cost?([anode(c: more) | _], _, cost) when more >= cost,
    do: false

  defp open_has_lower_cost?([anode(c: less) | rest], coords, cost) when less < cost,
    do: open_has_lower_cost?(rest, coords, cost)

  # defp open_has_lower_cost?(open, coords, cost) do
  #   IO.inspect(coords, label: "coords")
  #   IO.inspect(cost, label: "cost")
  #   IO.inspect(open, label: "open")
  #   raise "nomatch"
  # end

  # Manhattan distance

  def manhattan({from_x, from_y}, {to_x, to_y}),
    do: abs(from_x - to_x) + abs(from_y - to_y)

  # create path from closed list

  defp finalize_path(current, closed, path) do
    anode(parent_xy: parent_xy, coords: coords) = current

    case parent_xy do
      # Do not reverse(path) as we build it backwards from the
      # destination.
      # Also we do not set the root position in the path
      :root ->
        path

      other ->
        parent = Map.fetch!(closed, parent_xy)
        finalize_path(parent, closed, [coords | path])
    end
  end

  # finding neighbours

  defp move_coords({x, y}, :up), do: {x, y - 1}
  defp move_coords({x, y}, :down), do: {x, y + 1}
  defp move_coords({x, y}, :right), do: {x + 1, y}
  defp move_coords({x, y}, :left), do: {x - 1, y}

  defp cardinal_neighbours({_, _} = coords) do
    [
      move_coords(coords, :up),
      move_coords(coords, :down),
      move_coords(coords, :right),
      move_coords(coords, :left)
    ]
  end
end
