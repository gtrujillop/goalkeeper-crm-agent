defmodule StoreCRM.FailingCatalogue do
  @behaviour StoreCRM.Catalogue.Adapter
  def execute(_name, _arguments, _context), do: {:error, :shopify_unavailable}
end
