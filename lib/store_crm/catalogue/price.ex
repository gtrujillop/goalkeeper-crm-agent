defmodule StoreCRM.Catalogue.Price do
  def format(amount, currency, locale) do
    [whole | decimal] = String.split(amount, ".", parts: 2)
    separator = if String.starts_with?(locale, "es"), do: ".", else: ","

    grouped =
      whole
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(separator, &Enum.join/1)
      |> String.reverse()

    decimals = if decimal in [[], ["00"]], do: "", else: "," <> hd(decimal)
    "$#{grouped}#{decimals} #{currency}"
  end
end
