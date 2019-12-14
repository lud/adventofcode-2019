defmodule Day13 do
  # empty tile. No game object appears in this tile.
  @empty 0
  # wall tile. Walls are indestructible barriers.
  @wall 1
  # block tile. Blocks can be broken by the ball.
  @block 2
  # horizontal paddle tile. The paddle is indestructible.
  @paddle 3
  # is a ball
  @ball 4

  @joy_neutral 0
  @joy_left -1
  @joy_right 1

  def count_blocks(str) do
    {:ok, client} = Cpu.boot(str)

    {:halted, frame} =
      client
      |> full_first_frame(%{}, self())

    fake_score = 9999
    draw_frame(frame, fake_score)

    blocks_count =
      frame
      |> Enum.filter(fn
        {_, @block} -> true
        _ -> false
      end)
      |> length

    IO.inspect(blocks_count, label: "blocks_count")
  end

  def play(str) do
    # set memory address 0 to 2 to activate game loop
    this = self()

    printer =
      spawn_link(fn ->
        receive do
          {:client, client} ->
            IO.write(IO.ANSI.clear())
            ansi_printer_loop(client, this)
        end
      end)

    program =
      str
      |> Cpu.parse_program()
      |> Cpu.transform(fn [_ | ints] -> [2 | ints] end)
      |> Cpu.pipe_output(printer)

    {:ok, client} = Cpu.boot(program)
    send(printer, {:client, client})
    # we will automate the joystick
    # spawn_link(fn -> joystick_loop(this) end)
    game_loop(client, @joy_neutral)
  end

  def ansi_printer_loop(client, parent) do
    case Cpu.get_output(client, 3) do
      {:error, {:halted, {:ok, _}}} ->
        exit({:printer_halt})

      {:ok, [-1, 0, new_score]} ->
        render_ansi_score(new_score)

      {:ok, [x, y, tile_id]} ->
        send_tile(parent, tile_id, x, y)
        render_ansi_tile(x, y, tile_id)
    end

    ansi_printer_loop(client, parent)
  end

  def render_ansi_score(score) do
    [
      IO.ANSI.cursor(2, 3),
      "Score: #{score}"
    ]
    |> IO.write()
  end

  def render_ansi_tile(x, y, tile_id) do
    [
      # y;x, not x;y
      IO.ANSI.cursor(y + 3, x + 3),
      render_tile(tile_id)
    ]
    |> IO.write()
  end

  def printer_loop(client, parent) do
    {:ok, frame, score} = full_first_frame(client, %{}, parent)
    printer_loop(client, frame, score, parent)
  end

  def printer_loop(client, frame, score, parent) do
    {frame, score} =
      case Cpu.get_output(client, 3) do
        {:error, {:halted, {:ok, _}}} ->
          exit({:printer_halt})

        {:ok, [-1, 0, new_score]} ->
          {frame, new_score}

        {:ok, [x, y, tile_id]} ->
          send_tile(parent, tile_id, x, y)
          new_frame = Map.put(frame, {x, y}, tile_id)
          {new_frame, score}
      end

    draw_frame(frame, score)
    printer_loop(client, frame, score, parent)
  end

  defp send_tile(parent, tile_id, x, y) do
    case tile_id do
      @ball -> send(parent, {:ball_xy, x, y})
      @paddle -> send(parent, {:paddle_xy, x, y})
      _ -> nil
    end
  end

  defp full_first_frame(client, frame, parent) do
    case Cpu.get_output(client, 3) do
      {:error, {:halted, {:ok, _}}} ->
        {:halted, frame}

      {:ok, [-1, 0, score]} ->
        {:ok, frame, score}

      {:ok, [x, y, tile_id]} ->
        send_tile(parent, tile_id, x, y)
        frame = Map.put(frame, {x, y}, tile_id)
        full_first_frame(client, frame, parent)
    end
  end

  def game_loop(client, joystick_val, positions \\ {10, 1}) do
    positions = receive_positions(positions)

    joystick_val =
      case positions do
        {ball_x, paddle_x} when ball_x < paddle_x -> -1
        {ball_x, paddle_x} when ball_x > paddle_x -> 1
        _ -> 0
      end

    :ok = Cpu.send_input(client, joystick_val)
    Process.sleep(10)

    if Cpu.alive?(client) do
      game_loop(client, joystick_val, positions)
    end
  end

  defp receive_positions({default_ball_x, default_paddle_x}) do
    ball_x =
      receive do
        {:ball_xy, x, y} -> x
      after
        1000 ->
          default_ball_x
      end

    paddle_x =
      receive do
        {:paddle_xy, x, y} -> x
      after
        1000 ->
          default_paddle_x
      end

    {ball_x, paddle_x}
  end

  def read_joystick(default_val) do
    # We try to receive a value, if we get one we passe th received
    # value as default one, and then when there is no message (after
    # 0) we can return the last value. This will return the default
    # value if there is no message in queue
    receive do
      {:joystick, value} -> read_joystick(value)
    after
      0 -> default_val
    end
  end

  def joystick_loop(parent) do
    send(parent, {:joystick, read_joystick_input()})
    joystick_loop(parent)
  end

  def read_joystick_input() do
    case IO.getn("") do
      "q" ->
        @joy_left

      "d" ->
        @joy_right

      "s" ->
        @joy_neutral

      <<3>> ->
        exit(:interrupted)

      # ignore
      other ->
        IO.puts("\rwrong input: #{inspect(other)}")
        read_joystick_input()
    end
  end

  defp draw_frame(frame, score) do
    {max_x, max_y} = max_coords(frame)

    [
      "\r",
      for y <- 0..max_y do
        [
          "\r",
          for x <- 0..max_x do
            render_tile(Map.get(frame, {x, y}))
          end,
          "\n"
        ]
      end,
      "\n\rScore: #{score}"
    ]
    |> IO.puts()

    frame
  end

  defp render_tile(tile_id) do
    case tile_id do
      nil -> exit({:bad_tile, tile_id})
      @empty -> " "
      @wall -> "|"
      @block -> "#"
      @paddle -> "–"
      @ball -> "O"
    end
  end

  defp max_coords(frame) do
    frame
    |> Map.keys()
    |> Enum.reduce(fn {x, y}, {max_x, max_y} ->
      {max(x, max_x), max(y, max_y)}
    end)
  end
end

puzzle = File.read!("day13.puzzle")

# Day13.count_blocks(puzzle)
# |> IO.inspect()

# :debugger.start()
# :int.ni(Cpu)
# :int.break(Cpu, 186)

Day13.play(puzzle)
|> IO.inspect()

System.halt()
