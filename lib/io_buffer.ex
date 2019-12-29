defmodule IOBuffer do
  defstruct input: [], output: []

  def new() do
    %__MODULE__{}
  end

  def push(io, kind, value) when is_integer(value),
    do: push(io, kind, [value])

  def push(%{input: input} = io, :input, value) when is_list(value),
    do: %{io | input: input ++ value}

  def push(%{output: output} = io, :output, value) when is_list(value),
    do: %{io | output: output ++ value}

  def take(%{input: input} = io, :input) do
    [h | t] = input
    {h, %{io | input: t}}
  end

  def take(%{output: output} = io, :output) do
    [h | t] = output
    {h, %{io | output: t}}
  end

  def clear(io, :output) do
    %{io | output: []}
  end
end
