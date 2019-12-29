defmodule Day23 do
  @program File.read!("day23.puzzle") |> Cpu.parse_intcodes()
  @hub_name :network_hub
  @nat_address 255
  def run do
    # As soon as the Cpu are started they will want to send messages
    # but wee need the registry to relay their messages, and the
    # registry is created with their pid, so we need them to be
    # started.
    # Of course we could register them to a global registry, but this
    # is for fun.
    # So we will spawn a network hub and send it the registry when it
    # is complete, and only after receiving the registry will the hub
    # accept messages to relay.
    me = self()
    registry = %{@nat_address => spawn_link(fn -> nat_loop(me) end)}
    top = self()

    spawn_link(fn ->
      Process.register(self(), @hub_name)
      send(top, :ack)
      hub_init()
    end)

    # Await the registration of the process
    receive do
      :ack -> :ok
    end

    registry = Enum.reduce(0..49, registry, &spawn_cpu/2)

    send(@hub_name, {:registry, registry})
    # Finally we wait for the printer to complete
    receive_nat(%{})
  end

  defp receive_nat(map) do
    new_map =
      receive do
        {:nat_relayed, {:xy, x, y} = msg} ->
          IO.inspect(msg, label: "NAT msg to 0")

          case Map.fetch(map, y) do
            {:ok, 1} -> exit({:found_y, y})
            :error -> Map.put(map, y, 1)
          end
      end

    receive_nat(new_map)
  end

  defp hub_init() do
    receive do
      {:registry, registry} -> hub_loop(registry)
    end
  end

  defp hub_loop(registry) do
    receive do
      {:relay, address, msg} ->
        pid = Map.fetch!(registry, address)
        IO.puts("send to #{address}")
        send(pid, msg)

        hub_loop(registry)

      msg ->
        exit({:bad_msg, msg})
        # after
        # 1000 ->
        # hub_loop(registry)
    after
      100 ->
        send(self(), {:relay, @nat_address, :all_idle!})

        hub_loop(registry)
    end
  end

  defp nat_loop(parent) do
    nat_loop(parent, nil)
  end

  defp nat_loop(parent, last_msg) do
    receive do
      :all_idle! ->
        IO.puts("relay last msg")
        send(parent, {:nat_relayed, last_msg})
        send(@hub_name, {:relay, 0, last_msg})
        nat_loop(parent, last_msg)

      msg ->
        IO.puts("Nat received message: #{inspect(msg)}")
        nat_loop(parent, msg)
    end
  end

  defp spawn_cpu(address, registry) do
    pid =
      spawn_link(fn ->
        Process.put(:cpu, address)

        buffer =
          IOBuffer.new()
          |> IOBuffer.push(:input, address)
          |> IOBuffer.push(:input, -1)

        Cpu.run(@program, io: &handle_io/1, iostate: buffer)
      end)

    Map.put(registry, address, pid)
  end

  # When input is empty, we try to receive a new packet, immediately
  # give the X value, and store the y in the buffer. 
  defp handle_io({:input, %{input: []} = state}) do
    receive do
      {:xy, x, y} = packet ->
        {x, IOBuffer.push(state, :input, y)}

      msg ->
        exit({:bad_io_msg, msg})
    end
  end

  # While the input buffer is not empty, we will send its values
  defp handle_io({:input, state}) do
    {_val, _state} = IOBuffer.take(state, :input)
  end

  # If we have 2 values in output we can send the message and clear the output
  defp handle_io({:output, y, %{output: [address, x | []]} = state}) do
    send(@hub_name, {:relay, address, {:xy, x, y}})
    IOBuffer.clear(state, :output)
  end

  # If packet is not complete we will add the value to the buffer
  defp handle_io({:output, value, state}) do
    _state = IOBuffer.push(state, :output, value)
  end

  defp me do
    me(self(), Process.get(:cpu))
  end

  defp me(pid, address) do
    "<< #{inspect(pid)} | #{address} >>"
  end
end

Day23.run()
|> IO.inspect()
