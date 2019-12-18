defmodule GridMap do
  @type coords :: {x :: integer, y :: integer}
  @callback init() :: sate :: any
  @callback walkable?(coords, content :: any, state :: any) ::
              {bool, state :: any}
  @callback parse_content({coords, integer}, state :: any) :: {content :: any, state :: any}

  defstruct grid: %{}, mod: nil, state: nil, max_xy: nil, min_xy: {0, 0}

  @start_y 0
  @start_x 0

  def parse_map(str, mod) do
    this = %__MODULE__{mod: mod, state: mod.init()}

    this =
      str
      |> String.trim()
      |> to_charlist
      |> parse_chars(this, @start_x, @start_y)
  end

  defp parse_chars([?\n | chars], this, x, y),
    do: parse_chars(chars, this, @start_x, y + 1)

  defp parse_chars([char | chars], this, x, y) do
    %{state: state, mod: mod, grid: grid} = this
    coords = {x, y}
    {content, state} = mod.parse_content({coords, char}, state)
    grid = Map.put(grid, coords, content)
    this = %{this | state: state, grid: grid}
    parse_chars(chars, this, x + 1, y)
  end

  defp parse_chars([], this, x, y) do
    %{this | max_xy: {x, y}}
  end
end
