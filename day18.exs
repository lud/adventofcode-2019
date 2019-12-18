defmodule Vault do
  @behaviour GridMap
  def init() do
    %{
      # position of robot
      pos: nil,
      # keys laying on the floor
      keys: %{},
      # keys collected
      collected_keys: %{},
      doors: %{},
      open_doors: %{}
    }
  end

  @wall ?#
  @path ?.
  @entrance ?@

  def parse_content({_coords, @wall}, state),
    do: {@wall, state}

  def parse_content({_coords, @path}, state),
    do: {@path, state}

  def parse_content({coords, key}, state) when key >= ?a and key <= ?z do
    state = register_key(state, coords, key)
    {key, state}
  end

  def parse_content({coords, door}, state) when door >= ?A and door <= ?Z do
    state = register_door(state, coords, door)
    {door, state}
  end

  def parse_content({coords, @entrance}, state) do
    {@entrance, %{state | pos: coords}}
  end

  def parse_content({coords, char}, state) do
    raise "unknown content '#{[char]}'"
  end

  defp register_key(state, coords, key) do
    %{keys: fkeys} = state
    %{state | keys: Map.put(fkeys, coords, key)}
  end

  defp register_door(state, coords, door) do
    %{doors: doors} = state
    %{state | doors: Map.put(doors, coords, door)}
  end
end

defmodule Day18 do
  def run(str_map) do
    map = GridMap.parse_map(str_map, Vault)
  end
end

"""
#########
#b.A.@.a#
#########
"""
|> Day18.run()
|> IO.inspect()
