defmodule StoreCRM.Catalogue.Fake do
  @behaviour StoreCRM.Catalogue.Adapter
  def execute("search_products", arguments, context),
    do:
      {:ok,
       %{
         "products" => [
           %{
             "id" => "glove-1",
             "name" => "Guante Pro Turf",
             "price" => 189_900,
             "currency" => context.currency
           }
         ],
         "requirements" => arguments
       }}

  def execute(name, _arguments, _context), do: {:error, {:unknown_tool, name}}
end
