defmodule StoreCRM.CatalogueFixture do
  @behaviour StoreCRM.Catalogue.Adapter

  def execute("search_products", _arguments, context) do
    {:ok,
     %{
       "products" => [
         %{
           "id" => "gid://shopify/Product/1",
           "title" => "Guante Pro",
           "url" => "https://shop.test/products/guante-pro",
           "variants" => [
             %{
               "id" => "available",
               "available" => true,
               "price" => "189900.00",
               "currency" => context.currency,
               "display_price" => "$189.900 COP"
             },
             %{
               "id" => "sold-out",
               "available" => false,
               "price" => "179900.00",
               "currency" => context.currency
             }
           ],
           "purchasable_variants" => [%{"id" => "available", "available" => true}]
         }
       ]
     }}
  end

  def execute("create_cart", _arguments, context),
    do:
      {:ok,
       %{
         "id" => "gid://shopify/Cart/test",
         "checkout_url" => "https://shop.test/cart/c/test",
         "currency" => context.currency
       }}
end
