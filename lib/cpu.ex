defmodule Cpu do
  require IEx
  @timeout 5000
  defmodule State do
    @positional 0
    @immediate 1
    @relative 2

    defstruct memory: nil, cursor: 0, offset: 0, halted: false, iostate: nil, io: nil

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
      %State{this | memory: Map.put(mem, pos, value)}
    end

    defp cursor(%{cursor: pos}), do: pos
    def set_cursor(this, pos), do: %State{this | cursor: pos}

    defp memread(mem, pos) do
      Map.get(mem, pos, 0)
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

    def set_iostate(state, iostate) do
      %State{state | iostate: iostate}
    end
  end

  def run!(intcodes, opts \\ []) do
    case run(intcodes, opts) do
      {:ok, data} -> data
    end
  end

  def run(intcodes, opts \\ []) do
    program =
      intcodes
      |> parse_intcodes
      |> apply_opts(opts)
      |> loop()
  end

  defp apply_opts(state, opts) do
    Enum.reduce(opts, state, &apply_opt/2)
  end

  defp apply_opt({:transform, fun}, %State{memory: mem} = state) when is_function(fun, 1) do
    mem = fun.(State.to_list(state))
    State.reset_memory(state, mem)
  end

  defp apply_opt({:io, fun}, state) when is_function(fun, 1) do
    %State{state | io: fun}
  end

  defp apply_opt({:iostate, value}, state) do
    %State{state | iostate: value}
  end

  defp apply_opt(opt, _) do
    raise "Unknown option: #{inspect(opt)}"
  end

  defp parse_intcodes(str) do
    memory =
      str
      |> String.trim()
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

    State.new(memory)
  end

  defp loop(%{halted: true} = state),
    do: {:ok, state}

  defp loop(state) do
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
    [9, mode3, mode2, mode1, op1, op2] = Integer.digits(900_000 + int)
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
    %State{state | halted: true}
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
    {val, iostate} = state.io.({:input, state.iostate})

    state
    |> State.write(outpos, val)
    |> State.set_iostate(iostate)
  end

  # OUTPUT
  defp execute(state, %{op: 4, modes: modes}) do
    {{value}, state} = multiread(state, [:deref], modes)
    iostate = state.io.({:output, value, state.iostate})
    State.set_iostate(state, iostate)
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
