defmodule Cpu do
  require IEx
  @timeout 5000
  defmodule State do
    @positional 0
    @immediate 1
    @relative 2

    defstruct parent: nil, memory: nil, cursor: 0, offset: 0, output: nil

    def new(memory) when is_list(memory),
      do: reset_memory(%State{}, memory)

    def reset_memory(this, memory) when is_list(memory) do
      memory =
        memory
        |> Enum.with_index()
        |> Enum.map(fn {v, i} -> {i, v} end)
        |> Enum.into(%{})

      %State{this | memory: memory}
      |> IO.inspect()
    end

    def set_parent(this, parent) when is_pid(parent),
      do: %State{this | parent: parent}

    def read(%{memory: mem, offset: offset} = this, action \\ :offset, mode \\ @positional) do
      pos = cursor(this)
      val = memread(mem, pos)

      val =
        case {action, mode} do
          {:offset, @positional} -> val
          {:offset, @relative} -> offset + val
          {:deref, @positional} -> memread(mem, val)
          {:deref, @immediate} -> val
          {:deref, @relative} -> memread(mem, offset + val)
        end

      this = set_cursor(this, pos + 1)
      {val, this}
    end

    def write(%{memory: mem} = this, pos, value) do
      # IO.puts("write #{value} in #{pos}")
      %State{this | memory: Map.put(mem, pos, value)}
    end

    defp cursor(%{cursor: pos}), do: pos
    def set_cursor(this, pos), do: %State{this | cursor: pos}

    defp memread(mem, pos) do
      val = Map.get(mem, pos, 0)

      # IO.puts("read pos #{pos}: #{val}")
      val
    end

    def add_offset(%{offset: offset} = this, added) do
      %State{this | offset: offset + added}
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
    IO.puts("send input: #{val}")
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

  def pipe_output(%State{} = state, pid) when is_pid(pid),
    do: %State{state | output: pid}

  def get_output(client, n),
    do: get_output(client, n, [])

  defp get_output(client, 0, acc),
    do: {:ok, :lists.reverse(acc)}

  defp get_output(client, n, acc) do
    case get_output(client) do
      {:ok, output} ->
        get_output(client, n - 1, [output | acc])

      {:error, _} = err ->
        err
    end
  end

  def read_output(client),
    do: read_output(client, [])

  def read_output(client, acc) do
    case Cpu.get_output(client) do
      {:ok, value} ->
        IO.puts("output: #{value}")
        read_output(client, [value | acc])

      {:error, {:halted, {:ok, _}}} ->
        :lists.reverse(acc)

      {:error, {:halted, error}} ->
        error

      other ->
        exit({:bad_output, other})
    end
  end

  def alive?({:client, pid, ref}),
    do: Process.alive?(pid)

  def await({:client, pid, ref}) do
    if Process.alive?(pid) do
      receive do
        {:DOWN, ^ref, :process, ^pid, reason} ->
          halted_value(reason)
      after
        @timeout -> exit(:timeout)
      end
    else
      {:error, :noproc}
    end
  end

  def await!(client) do
    case await(client) do
      {:ok, data} -> data
      {:error, _} = err -> raise "program crashed: #{inspect(err)}"
    end
  end

  defp halted_value(reason) do
    case reason do
      {:ok, data} ->
        {:ok, data}

      reason ->
        IO.warn("Program exited with #{inspect(reason)}")
        {:error, reason}
    end
  end

  def transform(state, fun) do
    mem = fun.(State.to_list(state))
    State.reset_memory(state, mem)
  end

  def boot(program) when is_binary(program) do
    program
    |> parse_program
    |> boot
  end

  def boot(%State{} = state) do
    {pid, ref} =
      spawn_monitor(fn ->
        IO.puts("booted")
        loop(state)
      end)

    client = {:client, pid, ref}
    {:ok, client}
  end

  def parse_program(str) do
    memory =
      str
      |> String.trim()
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

    %State{parent: self(), output: self()}
    |> State.reset_memory(memory)
  end

  def loop(state) do
    {opcode, state} = State.read(state)
    com = parse_opcode(opcode)
    state = execute(state, com)
    # IO.inspect({opcode, state}, label: "{opcode, state}")
    loop(state)
  end

  defmodule Com do
    defstruct op: nil, modes: nil
  end

  defp parse_opcode(int) when is_integer(int) do
    [9, 0, mode3, mode2, mode1, op1, op2] = Integer.digits(9_000_000 + int)
    %Com{op: Integer.undigits([op1, op2]), modes: [mode1, mode2, mode3]}
  end

  defp multiread(state, actions, modes) do
    {rvals, state} =
      actions
      |> Enum.zip(modes)
      |> Enum.reduce({[], state}, fn {action, mode}, {vals, state} ->
        {val, state} = State.read(state, action, mode)
        {[val | vals], state}
      end)

    {List.to_tuple(:lists.reverse(rvals)), state}
  end

  # HALT
  defp execute(state, %{op: 99}) do
    IO.puts("program terminating")
    exit({:ok, State.to_list(state)})
  end

  # ADD
  defp execute(state, %{op: 1, modes: modes}) do
    {{arg1, arg2, outpos}, state} = multiread(state, [:deref, :deref, :offset], modes)
    State.write(state, outpos, arg1 + arg2)
  end

  # MULT
  defp execute(state, %{op: 2, modes: modes}) do
    {{arg1, arg2, outpos}, state} = multiread(state, [:deref, :deref, :offset], modes)
    State.write(state, outpos, arg1 * arg2)
  end

  # INPUT
  defp execute(state, %{op: 3, modes: modes}) do
    {{outpos}, state} = multiread(state, [:offset], modes)

    IO.puts("read input")

    receive do
      {:input, val} ->
        IO.puts("got input: #{val}")
        State.write(state, outpos, val)
    after
      @timeout -> exit({:timeout, :input})
    end
  end

  # OUTPUT
  defp execute(state, %{op: 4, modes: modes}) do
    {{value}, state} = multiread(state, [:deref], modes)

    if value == -1 do
      IO.puts("SEND SCORE")
    end

    send(state.output, {:output, self(), value})
    state
  end

  # JUMP_IF
  defp execute(state, %{op: 5, modes: modes}) do
    {{arg1, arg2}, state} = multiread(state, [:deref, :deref], modes)

    if arg1 != 0 do
      State.set_cursor(state, arg2)
    else
      state
    end
  end

  # JUMP_IFNOT
  defp execute(state, %{op: 6, modes: modes}) do
    {{arg1, arg2}, state} = multiread(state, [:deref, :deref], modes)

    if arg1 == 0 do
      State.set_cursor(state, arg2)
    else
      state
    end
  end

  # LESS_THAN
  defp execute(state, %{op: 7, modes: modes}) do
    {{arg1, arg2, outpos}, state} = multiread(state, [:deref, :deref, :offset], modes)
    val = if(arg1 < arg2, do: 1, else: 0)
    State.write(state, outpos, val)
  end

  # EQUALS
  defp execute(state, %{op: 8, modes: modes}) do
    {{arg1, arg2, outpos}, state} = multiread(state, [:deref, :deref, :offset], modes)
    val = if(arg1 == arg2, do: 1, else: 0)
    State.write(state, outpos, val)
  end

  # MOVEREL
  defp execute(state, %{op: 9, modes: modes}) do
    {{arg1}, state} = multiread(state, [:deref], modes)
    State.add_offset(state, arg1)
  end

  defp execute(_state, %{op: op}) do
    exit({:undef_op, op})
  end
end
