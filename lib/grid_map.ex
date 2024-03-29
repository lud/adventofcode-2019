defmodule GridMap do
  @type coords :: {x :: integer, y :: integer}

  @start_y 0
  @start_x 0

  def parse_map(str, read_fn \\ &default_read/2) do
    str
    |> String.trim()
    |> to_charlist
    |> parse_chars(%{}, @start_x, @start_y, read_fn)
  end

  def default_read(_, x), do: x

  defp parse_chars([?\n | chars], grid, x, y, read_fn),
    do: parse_chars(chars, grid, @start_x, y + 1, read_fn)

  defp parse_chars([char | chars], grid, x, y, read_fn) do
    coords = {x, y}

    grid =
      case read_fn.(coords, char) do
        :ignore -> grid
        content -> Map.put(grid, coords, content)
      end

    parse_chars(chars, grid, x + 1, y, read_fn)
  end

  defp parse_chars([], grid, _, _, _) do
    grid
  end

  def to_list(grid) do
    Enum.to_list(grid)
  end

  def reduce(grid, state, fun) when is_function(fun, 2) do
    Enum.reduce(grid, state, fun)
  end

  def fmap(grid, fun) when is_function(fun, 2) do
    grid
    |> Enum.map(fn {coords, content} ->
      new_content = fun.(coords, content)
      {coords, new_content}
    end)
    |> Enum.into(%{})
  end

  # reduce with fun/3 that also accepts the grid
  # def reduce(grid, state, fun) when is_function(fun, 3) do
  #   Enum.reduce(grid, state, fn elem, state -> fun.(elem, state, grid) end)
  # end

  def find(grid, default \\ nil, predicate),
    do: Enum.find(grid, default, predicate)

  # A* Algorithm
  #
  # - h = heuristic
  # - c = move cost from root
  require Record
  # A* node
  Record.defrecord(:anode, coords: nil, parent_xy: nil, h: nil, c: nil)

  def get_path!(grid, from, to, opts) do
    case get_path(grid, from, to, opts) do
      {:ok, path} -> path
      {:error, :no_path} -> raise "Could not find a path from #{inspect(from)} to #{inspect(to)}"
    end
  end

  def get_path(grid, from, to, walkable?) when is_function(walkable?) do
    get_path(grid, from, to, walkable?: walkable?)
    # @todo check if <from> and <to> are walkable    
  end

  def get_path(grid, from, to, opts) do
    walkable? =
      case Keyword.fetch!(opts, :walkable?) do
        fun when is_function(fun, 1) -> fn _coords, content -> fun.(content) end
        fun when is_function(fun, 2) -> fun
      end

    get_neighbours =
      case Keyword.fetch(opts, :neighbours) do
        {:ok, f} when is_function(f, 1) -> f
        :error -> &cardinal_neighbours/1
      end

    heuristic = Keyword.get(opts, :heuristic, &manhattan/2)

    astar_main(grid, from, to, walkable?, get_neighbours, heuristic)
  end

  defp astar_main(grid, from, to, walkable?, get_neighbours, heuristic) do
    # IO.puts("wal from #{inspect(from)} to #{inspect(to)}")
    parent_xy = :__root__
    root = anode(parent_xy: parent_xy, coords: from, h: 0, c: 0)
    open = [root]
    closed = %{}

    try do
      astar(grid, to, open, closed, walkable?, get_neighbours, heuristic)
    catch
      {:reached, path} -> {:ok, path}
    end
  end

  defp astar(_, _, [] = open, _, _, _, _),
    do: {:error, :no_path}

  defp astar(grid, to, open0, closed, walkable?, get_neighbours, heuristic) do
    [best | open1] = open0
    # IO.inspect(best, label: "Best")
    neighbour_cost = 1 + anode(best, :c)
    best_xy = anode(best, :coords)

    open2 =
      best
      |> anode(:coords)
      |> get_neighbours.()
      |> Enum.filter(fn coords -> walkable?.(coords, Map.get(grid, coords)) end)
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
        distance = heuristic.(coords, to)
        h = neighbour_cost + distance
        node = anode(parent_xy: best_xy, c: neighbour_cost, h: h, coords: coords)
        insert_node(open, node)
      end)

    closed = Map.put(closed, best_xy, best)
    astar(grid, to, open2, closed, walkable?, get_neighbours, heuristic)
  end

  # Insert a node on the open list. Objects are inserted in heuristic order

  def insert_node([anode(h: cur_h) = cur | open], anode(h: h) = n) when cur_h < h,
    do: [cur | insert_node(open, n)]

  def insert_node(open, n),
    # we have a lower heuristic than the tail now so we insert in the list
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
      :__root__ ->
        path

      other ->
        parent = Map.fetch!(closed, parent_xy)
        finalize_path(parent, closed, [coords | path])
    end
  end

  # finding neighbours

  def cardinal_neighbours({x, y}) do
    [{x, y - 1}, {x, y + 1}, {x + 1, y}, {x - 1, y}]
  end

  def render_map(grid) do
    render_map(grid, fn _, x -> x end)
  end

  def render_map(grid, render_tile) do
    {min_x, min_y} = min_coords(grid)
    {max_x, max_y} = max_coords(grid)

    for y <- min_y..max_y do
      for x <- min_x..max_x do
        render_tile.({x, y}, Map.get(grid, {x, y}))
      end
    end
  end

  def print_map(grid) do
    print_map(grid, fn _, x -> x end)
  end

  def print_map(grid, render_tile) do
    render_map(grid, render_tile)
    |> Enum.intersperse(?\n)
    |> IO.puts()

    grid
  end

  def move_coords(coords, direction, amount \\ 1)
  def move_coords({x, y}, :up, amount), do: {x, y - amount}
  def move_coords({x, y}, :down, amount), do: {x, y + amount}
  def move_coords({x, y}, :right, amount), do: {x + amount, y}
  def move_coords({x, y}, :left, amount), do: {x - amount, y}

  def max_coords(grid) do
    grid
    |> Map.keys()
    |> Enum.reduce({-999_999_999, -999_999_999}, fn
      {x, y}, {max_x, max_y} -> {max(x, max_x), max(y, max_y)}
      _, acc -> acc
    end)
  end

  def min_coords(grid) do
    grid
    |> Map.keys()
    |> Enum.reduce({:infinity, :infinity}, fn
      {x, y}, {min_x, min_y} -> {min(x, min_x), min(y, min_y)}
      _, acc -> acc
    end)
  end
end
