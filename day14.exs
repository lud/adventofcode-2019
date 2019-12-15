defmodule OreParser do
  import String, only: [trim: 1, split: 2, to_integer: 1]

  def parse_input(str) do
    str
    |> trim()
    |> split("\n")
    |> Enum.map(&parse_reaction/1)
  end

  def to_recipes(parsed) do
    parsed
    |> Enum.map(fn {comps, proded} ->
      {proded_qtty, proded_name} = proded
      {proded_name, {proded_qtty, comps}}
    end)
    |> Enum.into(%{})
  end

  defp parse_reaction(str) do
    [comps, proded] = split(str, "=>")

    comps =
      comps
      |> split(",")
      |> Enum.map(&parse_component/1)

    proded = parse_component(proded)
    {comps, proded}
  end

  defp parse_component(str) do
    [qtty, name] =
      str
      |> trim()
      |> split(" ")
      |> Enum.map(&trim/1)

    {to_integer(qtty), name}
  end

  def count_outputs(parsed) do
    have_multiple_recipes =
      parsed
      |> Enum.reduce(%{}, fn {_, {_, proded_name}}, acc ->
        Map.update(acc, proded_name, 1, &(&1 + 1))
      end)
      |> Enum.filter(fn {k, v} -> v > 1 end)
      |> Enum.map(fn {k, v} -> k end)

    IO.puts("#{length(have_multiple_recipes)} comps have multiple recipes")
  end
end

defmodule OreProd do
  def coef_base(), do: 2

  def produce(_recipes, {qtty, "ORE"}, inventory) do
    # IO.puts("Create #{qtty} ORE")
    throw({:out_of_ore, clean_inventory(inventory)})
    # inventory
    # |> Map.update("ORE", qtty, &(&1 + qtty))
    # |> Map.update(:created_ORE, qtty, &(&1 + qtty))
    IO.puts("collecting #{qtty} ORE")
    consume_comp(inventory, {qtty, "ORE"})
  end

  def produce(recipes, {qtty, target}, inventory) do
    # try do
    do_produce(recipes, {qtty, target}, inventory)
    # catch
    # :out_of_ore -> throw({:out_of_ore, inventory})
    # :out_of_ore -> throw({:out_of_ore, inventory})
    # end
  end

  def do_produce(recipes, {qtty, target}, inventory) do
    # IO.puts("produce [#{target}] #{qtty}")
    # Check if we have enough components to produce the target
    {qtty_proded, comps} = get_components(recipes, target)

    # raise "ici réserver ce qu'on va utiliser pour pas que ça soit pris pas les autres"

    missing_comps = get_missing_comps(inventory, comps)

    case missing_comps do
      [] ->
        inventory =
          inventory
          |> consume_comps(comps)
          |> collect_proded({qtty_proded, target})

        missing_target_qtty = qtty - qtty_proded

        if missing_target_qtty > 0 do
          produce(recipes, {missing_target_qtty, target}, inventory)
        else
          # if missing_target_qtty < 0 do
          #   IO.puts("produce overhead of #{-1 * missing_target_qtty} #{target}")
          # end

          inventory
        end

      # IO.puts("Produced #{qtty_proded} #{target}")

      [{comp_qtty, comp} | _] = list ->
        # IO.puts("require [#{Enum.join(Enum.map(list, fn {_, name} -> name end), ", ")}]")
        # produce 1 comp
        inventory =
          list
          |> Enum.reduce(inventory, fn {comp_qtty, comp}, inventory ->
            produce(recipes, {comp_qtty, comp}, inventory)
          end)

        # recurse on our target
        produce(recipes, {qtty, target}, inventory)
    end
  end

  defp mcoef({qtty, comp}, coef) do
    {qtty * coef, comp}
  end

  defp mcoef([{qtty, comp} | comps], coef) do
    [mcoef({qtty, comp}, coef) | mcoef(comps, coef)]
  end

  defp mcoef([], _),
    do: []

  defp merge_inventory(inv1, inv2) do
    Map.merge(inv1, inv2, fn _k, v1, v2 ->
      v1 + v2
    end)
  end

  def produce_max_fuel!(recipes, inventory, coef) do
    {:ok, data} = produce_max_fuel(recipes, inventory, coef)
    data
  end

  defp mcoef_recipes(recipes, coef) do
    recipes
    |> Enum.map(fn {k, {qtty, comps}} -> {k, {qtty * coef, mcoef(comps, coef)}} end)
    |> Enum.into(%{})
  end

  defp consume_leftovers(recipes, inventory) do
    # produce as much fuel a possible without using ORE
    ore = Map.get(inventory, "ORE", 0)
    no_ore_inventory = Map.put(inventory, "ORE", 0)
    no_ore_inventory = produce_with_leftovers(recipes, no_ore_inventory)
    Map.put(no_ore_inventory, "ORE", ore)
  end

  defp produce_with_leftovers(recipes, inventory) do
    try do
      {:ok, produce(recipes, {1, "FUEL"}, inventory)}
    catch
      {:out_of_ore, _} -> {:error, :out_of_ore}
    end
    |> case do
      {:ok, inventory} ->
        produce_with_leftovers(recipes, inventory)

      {:error, :out_of_ore} ->
        inventory
    end
  end

  defp produce_max_fuel(recipes, inventory, coef) do
    amount = coef
    coef_recipes = mcoef_recipes(recipes, coef)

    try do
      inventory = produce(coef_recipes, {amount, "FUEL"}, inventory)

      inventory =
        case coef do
          1 ->
            inventory

          _ ->
            consume_leftovers(mcoef_recipes(recipes, div(coef, coef_base())), inventory)
        end

      # inventory = consume_leftovers(recipes, inventory)
      # IO.puts("prod passed")
      {:ok, inventory}
    catch
      # {:out_of_ore, inventory} -> {:out_of_ore, inventory}
      {:out_of_ore, _some_inventory} -> {:out_of_ore, inventory}
    end
    |> case do
      {:ok, new_inventory} ->
        IO.puts(
          "Produced #{coef} FUEL (coef #{coef}), remaining ore: #{Map.get(new_inventory, "ORE")}"
        )

        produce_max_fuel(recipes, new_inventory, coef)

      {:out_of_ore, new_inventory} ->
        case coef do
          1 ->
            {:ok, new_inventory}

          more ->
            new_coef = div(coef, coef_base())
            IO.puts("New coef: #{new_coef}")
            # IO.inspect(new_inventory, label: "Inv")
            produce_max_fuel(recipes, new_inventory, new_coef)
        end
    end
  end

  # def reverse_prod(recipes, [], _postponed, inventory) do
  #   inventory
  # end

  # def reverse_prod(recipes, ["ORE" | rest], postponed, inventory) do
  #   reverse_prod(recipes, rest, postponed, inventory)
  # end

  # def reverse_prod(recipes, [source | sources], postponed, inventory) do
  #   {qtty_proded, comps} = get_components(recipes, source)

  #   if inventory_has(inventory, source, qtty_proded) do
  #     # IO.puts("reverse #{source}")

  #     inventory =
  #       inventory
  #       |> consume_comp({qtty_proded, source})
  #       |> collect_proded(comps)

  #     # |> clean_inventory

  #     comps_names = Enum.map(comps, fn {_, name} -> name end)
  #     # let the source in as long as we can reverse it
  #     reverse_prod(recipes, [source | comps_names] ++ sources, postponed, inventory)
  #   else
  #     reverse_prod(recipes, sources, [source | postponed], inventory)
  #   end
  # end

  # def loop_reverse_fuel(recipes, inventory \\ %{}) do
  #   target = 1_000_000_000_000
  #   # target = 1_000_000

  #   new_inventory = collect_proded(inventory, {1, "FUEL"})
  #   new_inventory = reverse_prod(recipes, ["FUEL"], [], new_inventory)
  #   current_ORE = Map.get(new_inventory, "ORE", 0)
  #   IO.puts("current_ORE: #{current_ORE}")
  #   IO.puts("target:      #{target}")

  #   if current_ORE < target do
  #     loop_reverse_fuel(recipes, new_inventory)
  #   else
  #     # return the previous inventory
  #     inventory
  #   end
  # end

  defp get_components(_recipes, "ORE"),
    do: {1, []}

  defp get_components(recipes, target) do
    Map.fetch!(recipes, target)
  end

  defp inventory_has(inv, k, value) do
    Map.get(inv, k, 0) >= value
  end

  defp get_missing_comps(inventory, [{qtty, comp} | comps]) do
    missing_qqty = qtty - Map.get(inventory, comp, 0)

    if missing_qqty > 0 do
      [{missing_qqty, comp} | get_missing_comps(inventory, comps)]
    else
      get_missing_comps(inventory, comps)
    end
  end

  defp get_missing_comps(_inventory, []),
    do: []

  defp consume_comps(inventory, [{qtty, comp} | comps]) do
    inventory
    |> consume_comp({qtty, comp})
    |> consume_comps(comps)
  end

  defp consume_comps(inventory, []),
    do: inventory

  defp consume_comp(inventory, {qtty, comp}) do
    # if comp == "ORE" do
    #   IO.puts("Consuming #{qtty} ORE")
    # end

    inventory
    |> Map.update!(comp, fn stock ->
      new_stock = stock - qtty

      if new_stock < 0 do
        # case comp do
        # "ORE" ->
        # throw(:out_of_ore)

        # _ ->
        IO.puts("Cannot consume #{qtty} #{comp} in #{inspect(inventory)}")

        throw({:cannot_consume, {qtty, comp}})
        # end
      end

      # IO.puts([
      #   IO.ANSI.yellow(),
      #   "[#{comp}] Consumed #{qtty}, #{stock} -> #{new_stock}",
      #   IO.ANSI.reset()
      # ])

      new_stock
    end)
  end

  def collect_proded(inventory, {qtty, comp}) do
    stock = Map.get(inventory, comp, 0)
    new_stock = stock + qtty

    # IO.puts([
    #   IO.ANSI.green(),
    #   "[#{comp}] Stored #{qtty}, #{stock} -> #{new_stock}",
    #   IO.ANSI.reset()
    # ])

    Map.put(inventory, comp, new_stock)
  end

  def collect_proded(inventory, [{qtty, comp} | comps]) do
    inventory
    |> collect_proded({qtty, comp})
    |> collect_proded(comps)
  end

  def collect_proded(inventory, []),
    do: inventory

  def clean_inventory(inventory) do
    inventory
    |> Enum.filter(fn
      {_, 0} -> false
      _ -> true
    end)
    |> Enum.into(%{})
  end

  def multiply_inventory(inventory, n) do
    inventory
    |> Enum.map(fn {k, v} -> {k, v * n} end)
    |> Enum.into(%{})
  end
end

recipes =
  "day14.puzzle"
  |> File.read!()
  |> OreParser.parse_input()
  |> OreParser.to_recipes()
  |> IO.inspect()

# inventory =
#   OreProd.produce(recipes, {1, "FUEL"}, %{:created_ORE => 0})
#   |> OreProd.clean_inventory()

# required_ore =
#   inventory
#   |> Map.get(:created_ORE)
#   |> IO.inspect(label: "created ORE")

# inventory
# |> Map.get("ORE")
# |> IO.inspect(label: "remaining ORE")

# # OreProd.produce_max_fuel(recipes, %{"ORE" => 1_000_000_000_000})
# OreProd.produce_max_fuel(recipes, %{"ORE" => 899_155})
# # OreProd.produce_max_fuel(recipes, %{"ORE" => 1_000_000})
# # OreProd.produce_fuel_until_clean(recipes, %{:created_ORE => 0})
# |> IO.inspect()

ore_1_fuel = 899_155

# inventory =
#   OreProd.produce(recipes, {1, "FUEL"}, %{"ORE" => 899_155}, 1)
#   |> OreProd.clean_inventory()
#   |> IO.inspect()

target = 1_000_000_000_000

start_coef =
  :math.pow(OreProd.coef_base(), 10)
  |> trunc()

  # start_coef =
  #   OreProd.coef_base()
  |> IO.inspect(label: "Start coef")

keep_ore = 10_000_000_000
inventory = OreProd.produce_max_fuel!(recipes, %{"ORE" => target - keep_ore}, start_coef)

inventory =
  inventory
  |> OreProd.collect_proded({keep_ore, "ORE"})
  |> IO.inspect(label: "Added #{keep_ore} ORE")

OreProd.produce_max_fuel!(recipes, inventory, 1)
|> IO.inspect(label: "Final inventory")
|> Map.get("FUEL")
|> IO.inspect(label: "Total fuel")

2_390_226
|> IO.inspect(label: "Old val   ")

# # raise "div trillion by ore, multiply all comps, consume leftovers"

# # OreProd.reverse_prod(recipes, ["FUEL"], [], %{"FUEL" => 1})

# # OreProd.loop_reverse_fuel(recipes)
# # |> IO.inspect()

System.halt()
