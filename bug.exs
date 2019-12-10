defmodule Bug do
  def run() do
    x = 123.456

    case x do
      :test ->
        thing =
          case myfun() do
            1 -> :ok
          end

        thing = stuff = Float.round(x, 5)
        {thing, stuff}
    end
  end

  def myfun do
    1
  end
end
