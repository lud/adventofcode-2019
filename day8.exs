defmodule Day8 do
  @transparent 2
  @black 0
  @white 1

  def run(pix, width, heigth) do
    ints =
      pix
      |> String.graphemes()
      |> Enum.map(&String.to_integer/1)

    layers =
      ints
      |> split_layers(width, heigth)

    {fewest_0_layer, _} =
      layers
      |> Enum.map(&index_with_0_count/1)
      |> Enum.reduce({nil, :infinity}, &min_0_count/2)

    fewest_0_layer_2_count = count_digits(fewest_0_layer, 2)
    fewest_0_layer_1_count = count_digits(fewest_0_layer, 1)
    IO.inspect(fewest_0_layer_1_count, label: "fewest_0_layer_1_count")
    IO.inspect(fewest_0_layer_1_count, label: "fewest_0_layer_1_count")
    IO.puts("2s * 1s: #{fewest_0_layer_2_count * fewest_0_layer_1_count}")

    image = assemble_layers(layers)
    print_image(image, width, heigth)
  end

  defp print_image(image, width, _heigth) do
    image
    |> Enum.chunk_every(width)
    |> Enum.map(&print_row/1)
  end

  defp print_row(pixs) do
    for pix <- pixs do
      case pix do
        @black -> IO.write(" ")
        @white -> IO.write("▩")
      end
    end

    IO.write("\n")
  end

  defp assemble_layers(layers) do
    # use bottom layer as acc
    layers = :lists.reverse(layers)
    Enum.reduce(layers, &add_layer_on_top/2)
  end

  defp add_layer_on_top([@transparent | layer], [current | image]),
    do: [current | add_layer_on_top(layer, image)]

  defp add_layer_on_top([pix | layer], [current | image]),
    do: [pix | add_layer_on_top(layer, image)]

  defp add_layer_on_top([], []),
    do: []

  defp count_digits(layer, digit, count \\ 0)

  defp count_digits([], _digit, count),
    do: count

  defp count_digits([digit | t], digit, count),
    do: count_digits(t, digit, count + 1)

  defp count_digits([_ | t], digit, count),
    do: count_digits(t, digit, count)

  defp index_with_0_count(layer) do
    count_0 =
      layer
      |> Enum.filter(&(&1 == 0))
      |> length

    {layer, count_0}
  end

  defp min_0_count({_, count_0} = candidate, {_, min_0} = acc) do
    if count_0 < min_0 do
      candidate
    else
      acc
    end
  end

  defp split_layers(ints, width, heigth, layers \\ [])

  defp split_layers([], width, heigth, layers),
    do: :lists.reverse(layers)

  defp split_layers(ints, width, heigth, layers) do
    {layer, ints} = shift_layer(ints, width, heigth)
    split_layers(ints, width, heigth, [layer | layers])
  end

  defp shift_layer(ints, width, heigth) do
    Enum.split(ints, width * heigth)
  end
end

"img.pix"
|> File.read!()
|> Day8.run(25, 6)
|> IO.inspect()

System.halt()
