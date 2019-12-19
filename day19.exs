defmodule Day19 do
  @program Cpu.parse_intcodes(
             "109,424,203,1,21102,1,11,0,1106,0,282,21101,0,18,0,1105,1,259,1201,1,0,221,203,1,21102,31,1,0,1105,1,282,21101,38,0,0,1106,0,259,20101,0,23,2,22102,1,1,3,21101,0,1,1,21101,0,57,0,1106,0,303,2101,0,1,222,21001,221,0,3,20102,1,221,2,21102,1,259,1,21102,1,80,0,1106,0,225,21101,33,0,2,21102,1,91,0,1106,0,303,1201,1,0,223,21002,222,1,4,21101,259,0,3,21101,0,225,2,21101,225,0,1,21101,0,118,0,1106,0,225,20101,0,222,3,21102,1,102,2,21102,133,1,0,1105,1,303,21202,1,-1,1,22001,223,1,1,21101,148,0,0,1106,0,259,2101,0,1,223,21001,221,0,4,21002,222,1,3,21101,0,15,2,1001,132,-2,224,1002,224,2,224,1001,224,3,224,1002,132,-1,132,1,224,132,224,21001,224,1,1,21102,195,1,0,106,0,108,20207,1,223,2,21001,23,0,1,21102,1,-1,3,21101,0,214,0,1105,1,303,22101,1,1,1,204,1,99,0,0,0,0,109,5,2102,1,-4,249,22101,0,-3,1,22101,0,-2,2,21202,-1,1,3,21101,250,0,0,1105,1,225,22102,1,1,-4,109,-5,2106,0,0,109,3,22107,0,-2,-1,21202,-1,2,-1,21201,-1,-1,-1,22202,-1,-2,-2,109,-3,2105,1,0,109,3,21207,-2,0,-1,1206,-1,294,104,0,99,22101,0,-2,-2,109,-3,2106,0,0,109,5,22207,-3,-4,-1,1206,-1,346,22201,-4,-3,-4,21202,-3,-1,-1,22201,-4,-1,2,21202,2,-1,-1,22201,-4,-1,1,22101,0,-2,3,21102,1,343,0,1106,0,303,1106,0,415,22207,-2,-3,-1,1206,-1,387,22201,-3,-2,-3,21202,-2,-1,-1,22201,-3,-1,3,21202,3,-1,-1,22201,-3,-1,2,22102,1,-4,1,21102,384,1,0,1106,0,303,1106,0,415,21202,-4,-1,-4,22201,-4,-3,-4,22202,-3,-2,-2,22202,-2,-4,-4,22202,-3,-2,-3,21202,-4,-1,-2,22201,-3,-2,1,21202,1,1,-4,109,-5,2106,0,0"
           )

  def run({rows, cols}) do
    max_x = rows - 1
    max_y = cols - 1

    all_coords =
      for x <- 0..max_x, y <- 0..max_y do
        {x, y}
      end
      |> IO.inspect()

    all_coords

    run_coords(all_coords, %{})
    |> IO.inspect()

    search_ship(make_fringes())
  end

  @ship_size 100

  defp search_ship(fringes) do
    # first search for any match
    # {high_y, fringes} = search_upper_bound(fringes, 2)

    # %{high_y: high_y}

    search_ship(fringes, 1)
  end

  defp search_ship(fringes, low_y) do
    case try_square(fringes, low_y) do
      # if it fits, mid becomes the high
      {:fit, square, fringes} ->
        IO.puts("exiting with y: #{low_y}")
        {:fit, square, _} = try_square(fringes, low_y)
        IO.inspect(square, label: "Square")
        {{top_left, top_right}, {bottom_left, bottom_right}} = square
        ship = {{bottom_left, low_y}, {bottom_left + @ship_size - 1, low_y + @ship_size - 1}}
        draw_map({bottom_left - 10, low_y - 10}, {@ship_size + 20, @ship_size + 20}, ship)
        x = max(top_left, bottom_left)
        y = low_y
        value = x * 10000 + y
        IO.puts("=> #{low_y} FITS !")
        exit({:value, value})

      # if it does not fit, mid is now the low

      {:unfit, fringes} ->
        IO.puts("=> #{low_y} does not fit !")
        IO.puts("expected low: #{low_y}")
        search_ship(fringes, low_y + 1)
    end
  end

  defp draw_map({orig_x, orig_y} = orig, {width, height}, ship) do
    {{ship_min_x, ship_min_y}, {ship_max_x, ship_max_y}} = ship

    for y <- orig_y..(orig_y + height) do
      [
        for x <- orig_x..(orig_x + width) do
          case {x, y} do
            {x, y}
            when x >= ship_min_x and x <= ship_max_x and y >= ship_min_y and y <= ship_max_y ->
              "X"

            other ->
              case read_coords(x, y) do
                0 -> "."
                1 -> "#"
              end
          end
        end,
        "\n"
      ]
    end
    |> IO.puts()

    IO.puts("Drawed map from #{inspect(orig)}, ship is at #{inspect({ship_min_x, ship_min_y})}")
  end

  def try_square(fringes, y) do
    {{left_x, right_x} = lr, fringes} = get_fringes(fringes, y)
    {{bottom_left_x, bottom_right_x} = bottom, fringes} = get_fringes(fringes, y + @ship_size - 1)
    # now check if the fringes 100 rows under are well aligned
    IO.inspect({lr, bottom}, label: "square")

    if fit_square(lr, bottom) do
      square =
        {lr, bottom}
        |> IO.inspect()

      {:fit, square, fringes}
    else
      {:unfit, fringes}
    end
  end

  defp search_upper_bound(fringes, y) do
    IO.puts("search upper bound: #{y}")
    # check if y has a width of at least 100
    {{left_x, right_x} = lr, fringes} = get_fringes(fringes, y)

    if right_x - left_x >= @ship_size - 1 do
      case try_square(fringes, y) do
        {:fit, _, fringes} ->
          {y, fringes}

        {:unfit, fringes} ->
          search_upper_bound(fringes, y + 200)
      end
    else
      # search_upper_bound(fringes, trunc(:math.pow(y, 2)))
      search_upper_bound(fringes, y + 200)
    end
  end

  defp fit_square({top_left, top_right} = top, {bottom_left, bottom_right} = bottom) do
    # we want to see if a square can fit in these rows.
    # top and left 'y' are separated by 100
    # To see if a square fit  min(right) - max(left) must be >= 100
    fits = min(top_right, bottom_right) - max(top_left, bottom_left) >= @ship_size - 1

    unless fits do
      IO.puts("Square #{inspect(top)} #{inspect(bottom)} does not fit")
      IO.puts(" - Left bound: #{max(top_left, bottom_left)}")
      IO.puts(" - Right bound: #{min(top_right, bottom_right)}")
    end

    fits
  end

  defp run_coords([], map) do
    GridMap.render_map(map, fn
      _, 0 -> "."
      _, 1 -> "#"
    end)
    |> Enum.with_index()
    |> Enum.map(fn {row, index} -> [String.pad_leading(to_string(index), 4), 32, row] end)
    |> Enum.intersperse(?\n)
    |> IO.puts()

    GridMap.reduce(map, 0, fn {_, pulled}, acc -> acc + pulled end)
  end

  defp make_fringes() do
    # We will look only for the borders of the beam. the first rows do
    # not overlap so we will generate them entirely
    fringes =
      0..6
      |> Enum.map(fn y ->
        beams =
          0..15
          |> Enum.map(fn x -> read_coords(x, y) end)
          |> Enum.with_index()
          # Drop the left no-beam cells
          |> Enum.drop_while(fn
            {0, _index} -> true
            _ -> false
          end)
          # Keep only the beam cells
          |> Enum.take_while(fn
            {1, _index} -> true
            _ -> false
          end)
          |> IO.inspect()

        [{1, left} | _] = beams
        {1, right} = List.last(beams)
        {y, {left, right}}
      end)
      |> Enum.into(%{})

    fringes
  end

  defp get_fringes(fringes, y) do
    IO.puts("get_fringes #{y}")

    case Map.fetch(fringes, y) do
      {:ok, xy} ->
        {xy, fringes}

      :error ->
        {{up_left_x, up_right_x}, fringes} = get_fringes(fringes, y - 1)
        # IO.puts("finding fringes for #{y}")
        # search the first beam to the right on the row, starting where
        # the upper left beam is
        # @todo optimise with binary search
        left_x = get_first_beam(up_left_x, y, :right)

        # search the last beam to the right too, starting where the upper
        # last beam is
        right_x = get_last_beam(up_right_x, y, :right)

        fringes = Map.put(fringes, y, {left_x, right_x})
        {{left_x, right_x}, fringes}
    end
  end

  @beam 1
  @void 0

  defp get_first_beam(x, y, direction) do
    case read_coords(x, y) do
      @beam -> x
      @void -> get_first_beam(move_x(x, direction), y, direction)
    end
  end

  defp get_last_beam(x, y, direction) do
    case read_coords(x, y) do
      @beam -> get_last_beam(move_x(x, direction), y, direction)
      @void -> x - 1
    end
  end

  defp move_x(x, :right), do: x + 1

  defp run_coords([{x, y} | coords], map) do
    map = Map.put(map, {x, y}, read_coords(x, y))
    run_coords(coords, map)
  end

  defp read_coords(x, y) do
    init_state = {x, y}

    io = fn
      {:input, {x, y}} ->
        {x, y}

      {:input, y} when is_integer(y) ->
        {y, nil}

      {:output, is_pulled, nil} ->
        # IO.inspect(is_pulled, label: "pulled? #{inspect(init_state)}")
        is_pulled
    end

    _pulled =
      Cpu.run!(@program,
        iostate: init_state,
        io: io
      )
      |> Map.get(:iostate)
  end
end

Day19.run({10, 10})
