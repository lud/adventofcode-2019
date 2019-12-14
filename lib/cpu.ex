defmodule Cpu do
  @timeout 5000
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
    await(client)
  end

  def send_input({:client, pid, _}, val) when is_integer(val) do
    send(pid, {:input, val})
    :ok
  end

  def get_output({:client, pid, ref}) do
    receive do
      {:output, ^pid, data} ->
        {:ok, data}

      {:DOWN, ^ref, :process, ^pid, reason} ->
        {:error, {:halted, halted_value(reason)}}
    end
  end

  def await({:client, pid, ref}) do
    receive do
      {:DOWN, ^ref, :process, ^pid, reason} ->
        halted_value(reason)
    after
      @timeout -> exit(:timeout)
    end
  end

  defp halted_value(reason) do
    case reason do
      {:ok, data} ->
        {:ok, data}

      :timeout ->
        exit(:timeout)

      reason ->
        IO.warn("Program exited with #{inspect(reason)}")
        {:error, reason}
    end
  end

  def await!(client) do
    case await(client) do
      {:ok, data} -> data
      {:error, reason} = err -> raise "program crashed: #{inspect(err)}"
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
    [9, 0, mode3, mode2, mode1, op1, op2] = Integer.digits(9_000_000 + int)
    %Com{op: Integer.undigits([op1, op2]), modes: [mode1, mode2, mode3]}
  end

  # HALT
  defp execute(state, %{op: 99}) do
    exit({:ok, State.to_list(state)})
  end

  defp multiread(state, actions, modes \\ []) do
    {rvals, state} =
      actions
      |> Enum.zip(modes)
      |> Enum.reduce({[], state}, fn {action, _mode}, {vals, state} ->
        {val, state} = State.read(state, action)
        {[val | vals], state}
      end)

    {List.to_tuple(:lists.reverse(rvals)), state}
  end

  # ADD
  defp execute(state, %{op: 1, modes: modes}) do
    {{arg1, arg2, outpos}, state} = multiread(state, [:deref, :deref, :raw], modes)
    State.write(state, outpos, arg1 + arg2)
  end

  # MULT
  defp execute(state, %{op: 2, modes: modes}) do
    {{arg1, arg2, outpos}, state} = multiread(state, [:deref, :deref, :raw], modes)
    State.write(state, outpos, arg1 * arg2)
  end

  # INPUT
  defp execute(state, %{op: 3, modes: modes}) do
    {{outpos}, state} = multiread(state, [:raw], modes)

    receive do
      {:input, val} ->
        State.write(state, outpos, val)
    after
      @timeout -> exit(:timeout)
    end
  end

  # OUTPUT
  defp execute(state, %{op: 4, modes: modes}) do
    {{value}, state} = multiread(state, [:deref], modes)
    send(state.parent, {:output, self(), value})
    state
  end

  defp execute(_state, %{op: op}) do
    exit({:undef_op, op})
  end
end
