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
      |> full_first_frame()

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
    printer =
      spawn_link(fn ->
        receive do
          {:client, client} -> printer_loop(client)
        end
      end)

    program =
      str
      |> Cpu.parse_program()
      |> Cpu.transform(fn [_ | ints] -> [2 | ints] end)
      |> Cpu.pipe_output(printer)
      |> IO.inspect()

    {:ok, client} = Cpu.boot(program)
    send(printer, {:client, client})
    this = self()
    spawn_link(fn -> joystick_loop(this) end)
    game_loop(client, @joy_neutral)
  end

  def printer_loop(client) do
    {:ok, frame, score} = full_first_frame(client)
    printer_loop(client, frame, score)
  end

  def printer_loop(client, frame, score) do
    {frame, score} =
      case Cpu.get_output(client, 3) do
        {:error, {:halted, {:ok, _}}} ->
          exit({:printer_halt})
          {:halted, frame}

        {:ok, [-1, 0, new_score]} ->
          {frame, new_score}

        {:ok, [x, y, tile_id]} ->
          new_frame = Map.put(frame, {x, y}, tile_id)
          {new_frame, score}
      end

    draw_frame(frame, score)
    printer_loop(client, frame, score)
  end

  def game_loop(client, joystick_val) do
    joystick_val = read_joystick(joystick_val)
    :ok = Cpu.send_input(client, joystick_val)
    Process.sleep(500)

    if Cpu.alive?(client) do
      game_loop(client, joystick_val)
    end
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

  defp full_first_frame(client, frame \\ %{})

  defp full_first_frame(client, frame) do
    case Cpu.get_output(client, 3) do
      {:error, {:halted, {:ok, _}}} ->
        {:halted, frame}

      {:ok, [-1, 0, score]} ->
        {:ok, frame, score}

      {:ok, [x, y, tile_id]} ->
        frame = Map.put(frame, {x, y}, tile_id)
        full_first_frame(client, frame)
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
            case Map.get(frame, {x, y}) do
              nil -> exit({:bad_tile, x, y, frame})
              @empty -> " "
              @wall -> "|"
              @block -> "#"
              @paddle -> "="
              @ball -> "O"
            end
          end,
          "\n"
        ]
      end,
      "\n\rScore: #{score}"
    ]
    |> IO.puts()

    frame
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
