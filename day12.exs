defmodule Moon do
  defstruct pos: nil, vel: {0, 0, 0}, index: nil
  @m __MODULE__
  def new({x, y, z} = pos) do
    %@m{pos: pos}
  end

  def set_index(moon, index),
    do: %@m{moon | index: index}

  def update_vel(%@m{vel: {vx, vy, vz}} = this, :x, n),
    do: %@m{this | vel: {vx + n, vy, vz}}

  def update_vel(%@m{vel: {vx, vy, vz}} = this, :y, n),
    do: %@m{this | vel: {vx, vy + n, vz}}

  def update_vel(%@m{vel: {vx, vy, vz}} = this, :z, n),
    do: %@m{this | vel: {vx, vy, vz + n}}

  def apply_velocity(%@m{pos: {x, y, z}, vel: {vx, vy, vz}} = this) do
    %@m{this | pos: {x + vx, y + vy, z + vz}}
  end

  def total_energy(this) do
    potential_energy(this) * kinetic_energy(this)
  end

  defp potential_energy(%@m{pos: pos}),
    do: sum_abs(pos)

  defp kinetic_energy(%@m{vel: vel}),
    do: sum_abs(vel)

  defp sum_abs({a, b, c}),
    do: abs(a) + abs(b) + abs(c)
end

defmodule Day12 do
  @re_line ~r/^<x=([0-9-]+), y=([0-9-]+), z=([0-9-]+)>$/
  def parse_input(str) do
    str
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(fn line ->
      Regex.run(@re_line, line, capture: :all_but_first)
      |> Enum.map(&String.to_integer/1)
      |> List.to_tuple()
    end)
    |> Enum.map(&Moon.new/1)
    |> Enum.with_index()
    |> Enum.map(fn {moon, index} -> Moon.set_index(moon, index) end)
  end

  def step(moons, 0, receiver),
    do: send_moons(moons, receiver)

  def step(moons, n, receiver) do
    if rem(n, 10000) == 0 do
      # IO.puts("syncing")
      Receiver.sync(receiver)
    end

    moons
    |> send_moons(receiver)
    |> compute_step
    |> step(n - 1, receiver)
  end

  defp send_moons(moons, pid) do
    send(pid, moons)
    moons
  end

  def step_nrj(moons, n, acc \\ %{})

  def step_nrj(moons, 0, acc),
    do: {moons, acc}

  def step_nrj(moons, n, acc) do
    moons =
      moons
      |> compute_step

    nrj = compute_energy(moons)
    ## increment the entry for this energy in map
    acc = Map.update(acc, nrj, 1, &(&1 + 1))
    step_nrj(moons, n - 1, acc)
  end

  defp compute_step(moons) do
    moons
    |> apply_gravity
    |> apply_velocity
  end

  def compute_energy(moons) do
    moons
    |> Enum.map(&Moon.total_energy/1)
    |> Enum.sum()
  end

  defp apply_velocity(moons) do
    Enum.map(moons, &Moon.apply_velocity/1)
  end

  # compare the current moon to each of the others
  # then do the same with the others, recursively, so each moon is
  # compared only once to all others
  defp apply_gravity([moon | []]) do
    [moon]
  end

  defp apply_gravity([first | moons]) do
    {first, moons} = update_gravity(first, moons)
    [first | apply_gravity(moons)]
  end

  # Compare each "others" to the moon and update
  defp update_gravity(moon, others, acc \\ [])

  defp update_gravity(moon, [], acc) do
    {moon, acc}
  end

  defp update_gravity(moon, [other | others], acc) do
    {add_x, add_x_2} = cal_vel_change(moon, other, :x)
    {add_y, add_y_2} = cal_vel_change(moon, other, :y)
    {add_z, add_z_2} = cal_vel_change(moon, other, :z)
    # comparing positions, we will then update the velocity with those
    # comparisons. add_x, y, z etc. are either -1, 0 or 1
    moon =
      moon
      |> Moon.update_vel(:x, add_x)
      |> Moon.update_vel(:y, add_y)
      |> Moon.update_vel(:z, add_z)

    other =
      other
      |> Moon.update_vel(:x, add_x_2)
      |> Moon.update_vel(:y, add_y_2)
      |> Moon.update_vel(:z, add_z_2)

    update_gravity(moon, others, [other | acc])
  end

  defp cal_vel_change(%Moon{pos: {x, y, z}}, %Moon{pos: {x2, y2, z2}}, pos) do
    case pos do
      :x -> vel_modifier(x, x2)
      :y -> vel_modifier(y, y2)
      :z -> vel_modifier(z, z2)
    end
  end

  # > if Ganymede has an x position of 3, and Callisto has a x
  # > position of 5, then Ganymede's x velocity changes by +1 (because
  # > 5 > 3) and Callisto's x velocity changes by -1 (because 3 < 5)
  # So the smallest int got +1 (small moon is pulled to the other)
  # The exercise does not seem to take negative values in account.
  # For example if Ganymède has x: 10 and Europe x: -2, velocity
  # of Europe will be vx+1. but as -2 is negative, Europe is not
  # pulled, it is pushed away
  defp vel_modifier(n, n), do: {0, 0}
  defp vel_modifier(n, m) when n > m, do: {-1, 1}
  defp vel_modifier(n, m) when n < m, do: {1, -1}
end

defmodule Receiver do
  def run() do
    run(%{step: -1, trees: %{}})
  end

  def stop(pid) do
    send(pid, {:stop, self()})

    receive do
      {:stopped, data} -> data
    end
  end

  def sync(pid) do
    send(pid, {:sync, self()})

    receive do
      :synced -> :ok
    end
  end

  def run(state) do
    receive do
      {:stop, pid} ->
        send(pid, {:stopped, :not_found})
        :ok

      {:sync, pid} ->
        send(pid, :synced)
        run(state)

      moons ->
        case check_same_state(state, moons) do
          {:repetitions, repeats} ->
            calc_repeats(state, repeats)

          {:found, data, state} ->
            IO.puts("found #{data}, await stop")
            await_stop(state, moons)

          state ->
            run(state)
        end
    end
  end

  defp calc_repeats(state, repeats) do
    # repeats
    # |> Enum.sort()
    # |> Enum.reverse()
    repeats = IO.inspect(repeats, label: "repeats")

    data = reduce_cycles(repeats, Enum.max(repeats))

    await_stop(state, data)
  end

  # if the current step is divisible by the larger cycle, go to the next cycle
  defp reduce_cycles(cycles, step) do
    exit("@todo must find least common divisor of #{inspect(cycles)}")
  end

  def await_stop(_state, data) do
    # IO.puts("awaiting stop")

    receive do
      {:stop, pid} ->
        send(pid, {:stopped, {:found, data}})

      other ->
        # IO.puts("discard #{inspect(other)}")
        await_stop(_state, data)
    after
      1000 ->
        await_stop(_state, data)
    end
  end

  # def member([other | sorted], key) when other < key,
  #   do: member(sorted, key)

  # def member([key | sorted], key) do
  #   true
  # end

  # def member(_, _),
  #   do: false

  def member(map, key),
    do: Map.has_key?(map, key)

  def insert(map, key),
    do: Map.put(map, key, 1)

  # def insert([cand | sorted], key) when cand < key, do: [cand | insert(sorted, key)]
  # def insert([], key), do: [key]
  # def insert(sorted, key), do: [key | sorted]

  defp check_same_state(state, moons) do
    moons = sort_by_index(moons)
    nrj = Day12.compute_energy(moons)
    {key_x, key_y, key_z} = serialize(moons)

    %{step: step, trees: trees} = state
    step = step + 1

    if rem(step, 10000) == 0 do
      IO.puts("step #{step}")
    end

    {set_x, set_y, set_z} = Map.get(trees, :only_one_set, empty_tree())
    {repeated_x, set_x} = check(set_x, key_x, step, :x)
    {repeated_y, set_y} = check(set_y, key_y, step, :y)
    {repeated_z, set_z} = check(set_z, key_z, step, :z)
    tree = {set_x, set_y, set_z}

    if repeated_x and Process.get(:repeat_x) == nil do
      IO.puts("x repeated at step #{step}")
      Process.put(:repeat_x, step)
    end

    if repeated_y and Process.get(:repeat_y) == nil do
      IO.puts("y repeated at step #{step}")
      Process.put(:repeat_y, step)
    end

    if repeated_z and Process.get(:repeat_z) == nil do
      IO.puts("z repeated at step #{step}")
      Process.put(:repeat_z, step)
    end

    if Process.get(:repeat_x) != nil and Process.get(:repeat_y) != nil and
         Process.get(:repeat_z) != nil do
      {:repetitions, [Process.get(:repeat_x), Process.get(:repeat_y), Process.get(:repeat_z)]}
      |> IO.inspect()
    else
      trees = Map.put(trees, :only_one_set, tree)
      state = %{step: step, trees: trees}
    end
  end

  def empty_tree() do
    {empty_set(-1), empty_set(-2), empty_set(-3)}
  end

  def empty_set(rand_init_val) do
    # keys, last found step
    {%{}, rand_init_val}
  end

  def check({keys, step}, key, new_step, debug) do
    # IO.puts("keys: #{inspect(keys)}")

    if member(keys, key) do
      # IO.puts("found a repeat for #{debug} : #{inspect(key)} at step #{new_step}")
      # IO.puts("key: #{inspect(key)}")
      # IO.puts("#{debug} : #{new_step}")
      {true, {keys, new_step}}
    else
      {false, {insert(keys, key), step}}
    end
  end

  defp serialize([
         %{pos: {x1, y1, z1}, vel: {vx1, vy1, vz1}},
         %{pos: {x2, y2, z2}, vel: {vx2, vy2, vz2}},
         %{pos: {x3, y3, z3}, vel: {vx3, vy3, vz3}},
         %{pos: {x4, y4, z4}, vel: {vx4, vy4, vz4}}
       ]) do
    {
      {x1, x2, x3, x4, vx1, vx2, vx3, vx4},
      {y1, y2, y3, y4, vy1, vy2, vy3, vy4},
      {z1, z2, z3, z4, vz1, vz2, vz3, vz4}
    }
  end

  def draw_2s_map(state) do
    poss = Map.keys(state)
    xs = Enum.map(poss, fn {x, _, _} -> x end)
    ys = Enum.map(poss, fn {_, y, _} -> y end)
    xys = Enum.map(poss, fn {x, y, _} -> {x, y} end)
    min_x = Enum.min(xs)
    max_x = Enum.max(xs)
    min_y = Enum.min(ys)
    max_y = Enum.max(ys)
    IO.inspect({min_x, min_y, max_x, max_y})

    for y <- min_y..max_y do
      for x <- min_x..max_x do
        if :lists.member({x, y}, xys) do
          "#"
        else
          "."
        end
        |> IO.write()
      end

      IO.write("\n")
    end
  end

  def sort_by_index([%{index: 0} = a, b, c, d]),
    do: [a | sort_by_index(b, c, d)]

  def sort_by_index([a, %{index: 0} = b, c, d]),
    do: [b | sort_by_index(a, c, d)]

  def sort_by_index([a, b, %{index: 0} = c, d]),
    do: [c | sort_by_index(a, b, d)]

  def sort_by_index([a, b, c, %{index: 0} = d]),
    do: [d | sort_by_index(a, b, d)]

  def sort_by_index(%{index: 1} = b, c, d),
    do: [b | sort_by_index(c, d)]

  def sort_by_index(b, %{index: 1} = c, d),
    do: [c | sort_by_index(b, d)]

  def sort_by_index(b, c, %{index: 1} = d),
    do: [d | sort_by_index(b, c)]

  def sort_by_index(%{index: 2} = c, d),
    do: [c, d]

  def sort_by_index(c, d),
    do: [d, c]

  def print_moons(moons, header) do
    header

    text =
      moons
      |> sort_by_index
      |> Enum.map(fn %Moon{pos: {x, y, z}, vel: {vx, vy, vz}} ->
        "pos=< x:#{pad(x)} y:#{pad(y)} z:#{pad(z)}> vel=<x:#{pad(vx)} y:#{pad(vy)} z:#{pad(vz)} >\n"
      end)

    IO.puts([header, "\n", text])
    moons
  end

  defp pad(x) do
    x
    |> to_string
    |> String.pad_leading(3)
  end
end

receiver = spawn_link(&Receiver.run/0)

"""
<x=-1, y=0, z=2>
<x=2, y=-10, z=-7>
<x=4, y=-8, z=8>
<x=3, y=5, z=-1>
"""

moons =
  """
  <x=16, y=-8, z=13>
  <x=4, y=10, z=10>
  <x=17, y=-5, z=6>
  <x=13, y=-3, z=0>
  """
  # 
  # 
  |> Day12.parse_input()
  |> IO.inspect()

IO.puts("init energy: #{Day12.compute_energy(moons)}")

moons
|> Day12.step(9_999_999_999_999_999, receiver)
|> Receiver.print_moons("RESULT")

# |> IO.inspect()

case Receiver.stop(receiver) do
  {:found, data} ->
    # IO.puts("received found: #{inspect(data)}")
    nil

  # Receiver.print_moons(moons, "FOUND")
  # IO.puts("found energy: #{Day12.compute_energy(moons)}")

  :not_found ->
    IO.puts("received not found")
    :ok

  other ->
    exit({:bad_msg, other})
end

System.halt()
