defmodule Cpu do
  defmodule State do
    @positional 0
    @immediate 1
    @relative 2

    defstruct parent: nil, memory: [], cursor: 0

    def new(memory) when is_list(memory),
      do: reset_memory(%State{}, memory)

    def reset_memory(this, memory) when is_list(memory) do
      memory =
        memory
        |> Enum.with_index()
        |> Enum.map(fn {v, i} -> {i, v} end)
        |> Enum.into(%{})

      %State{this | memory: memory}
    end

    def set_parent(this, parent) when is_pid(parent),
      do: %State{this | parent: parent}

    def read(%{memory: mem} = this, action \\ :raw) do
      pos = cursor(this)
      val = memread(mem, pos)

      val =
        case action do
          :raw -> val
          :deref -> memread(mem, val)
        end

      this = set_cursor(this, pos + 1)
      {val, this}
    end

    def write(%{memory: mem} = this, pos, value) do
      IO.puts("write #{value} in #{pos}")
      %State{this | memory: Map.put(mem, pos, value)}
    end

    defp cursor(%{cursor: pos}), do: pos
    defp set_cursor(this, pos), do: %State{this | cursor: pos}

    defp memread(mem, pos) do
      val =
        Map.get_lazy(mem, pos, fn ->
          IO.puts("Failed to read position #{pos}, return 0")
          0
        end)

      IO.puts("read pos #{pos}: #{val}")
      val
    end

    def to_list(%{memory: mem}) do
      max_key = Enum.max(Map.keys(mem))

      for i <- 0..max_key do
        memread(mem, i)
      end
    end
  end

  def run!(program) do
    case run(program) do
      {:ok, data} -> data
      {:error, code} -> raise "Program exited with code #{inspect(code)}"
    end
  end

  def run(program) do
    {:ok, client} = boot(program)
    # sendcom(client, :run)
    await_halt(client)
  end

  # defp sendcom({:client, pid, _}, command) do
  #   send(pid, {:com, command})
  # end

  def await_halt({:client, pid, ref}) do
    receive do
      {:DOWN, ^ref, :process, ^pid, reason} ->
        case reason do
          {:ok, data} ->
            {:ok, data}

          reason ->
            IO.warn("Program exited with #{inspect(reason)}")
            {:error, reason}
        end
    after
      5000 -> exit(:timeout)
    end
  end

  def boot(program) when is_binary(program) do
    program
    |> parse_program
    |> boot
  end

  def boot(program) when is_list(program) do
    parent = self()

    {pid, ref} =
      spawn_monitor(fn ->
        state =
          program
          |> State.new()
          |> State.set_parent(parent)

        IO.puts("program booting: #{inspect(program)}")

        loop(state)
      end)

    client = {:client, pid, ref}
    {:ok, client}
  end

  defp parse_program(str) do
    str
    |> String.trim()
    |> String.split(",")
    |> Enum.map(&String.to_integer/1)
  end

  def loop(state) do
    {opcode, state} = State.read(state)
    com = parse_opcode(opcode)
    state = execute(state, com)
    IO.inspect({opcode, state}, label: "{opcode, state}")
    loop(state)
  end

  defmodule Com do
    defstruct op: nil, modes: nil
  end

  defp parse_opcode(int) when is_integer(int) do
    [9, mode3, mode2, mode1, op1, op2] = Integer.digits(900_000 + int)
    %Com{op: Integer.undigits([op1, op2]), modes: [nil, mode1, mode2, mode3]}
  end

  # HALT
  defp execute(state, %{op: 99}) do
    exit({:ok, State.to_list(state)})
  end

  # ADD
  defp execute(state, %{op: 1, modes: _modes}) do
    {arg1, state} = State.read(state, :deref)
    {arg2, state} = State.read(state, :deref)
    {outpos, state} = State.read(state)
    State.write(state, outpos, arg1 + arg2)
  end

  defp execute(_state, %{op: op}) do
    exit({:undef_op, op})
  end
end
