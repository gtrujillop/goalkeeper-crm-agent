defmodule StoreCRM.Catalogue.Shopify do
  @behaviour StoreCRM.Catalogue.Adapter
  alias StoreCRM.Catalogue.Price
  alias StoreCRM.Stores

  @search ~S|query Search($query: String!, $country: CountryCode!) @inContext(country: $country) { products(first: 10, query: $query) { nodes { id title handle onlineStoreUrl variants(first: 25) { nodes { id title availableForSale quantityAvailable price { amount currencyCode } } } } } }|
  @cart ~S|mutation Cart($input: CartInput!) { cartCreate(input: $input) { cart { id checkoutUrl cost { totalAmount { currencyCode } } } userErrors { field message } } }|

  def execute(name, arguments, context) when name in ["search_products", "create_cart"] do
    store = Stores.get_profile!(context.store_profile_id)

    with {:ok, configuration} <- configuration(store),
         {:ok, data} <- request(configuration, name, arguments, context),
         {:ok, result} <- normalize(name, data, context) do
      {:ok, result}
    end
  end

  def execute(name, _arguments, _context), do: {:error, {:unknown_tool, name}}

  @doc false
  def normalize_response(name, data, context), do: normalize(name, data, context)

  defp configuration(store) do
    configuration = %{
      domain: store.shopify_shop_domain || System.get_env("SHOPIFY_SHOP_DOMAIN"),
      token: System.get_env("SHOPIFY_STOREFRONT_PRIVATE_TOKEN"),
      api_version:
        store.shopify_api_version ||
          System.get_env("SHOPIFY_STOREFRONT_API_VERSION", "2026-07")
    }

    if Enum.all?(configuration, fn {_key, value} -> is_binary(value) and value != "" end) do
      {:ok, configuration}
    else
      {:error, :shopify_not_configured}
    end
  end

  defp request(configuration, name, arguments, context) do
    {query, variables} =
      case name do
        "search_products" ->
          {@search, %{query: value(arguments, "query", ""), country: context.market}}

        "create_cart" ->
          {@cart,
           %{
             input: %{
               lines: value(arguments, "lines", []),
               buyerIdentity: %{countryCode: context.market}
             }
           }}
      end

    url = "https://#{configuration.domain}/api/#{configuration.api_version}/graphql.json"

    case Req.post(url,
           json: %{query: query, variables: variables},
           headers: [{"shopify-storefront-private-token", configuration.token}]
         ) do
      {:ok, %{status: 200, body: %{"data" => data}}} -> {:ok, data}
      {:ok, %{status: status}} -> {:error, {:shopify_http_error, status}}
      {:error, reason} -> {:error, {:shopify_unavailable, reason}}
    end
  end

  defp normalize("search_products", %{"products" => %{"nodes" => products}}, context),
    do: {:ok, %{"products" => Enum.map(products, &product(&1, context))}}

  defp normalize(
         "create_cart",
         %{"cartCreate" => %{"cart" => cart, "userErrors" => []}},
         _context
       )
       when not is_nil(cart),
       do:
         {:ok,
          %{
            "id" => cart["id"],
            "checkout_url" => cart["checkoutUrl"],
            "currency" => get_in(cart, ["cost", "totalAmount", "currencyCode"]),
            "raw" => cart
          }}

  defp normalize("create_cart", %{"cartCreate" => %{"userErrors" => errors}}, _context),
    do: {:error, {:shopify_validation, errors}}

  defp normalize(_name, body, _context), do: {:error, {:invalid_shopify_response, body}}

  defp product(product, context) do
    variants = Enum.map(product["variants"]["nodes"], &variant(&1, context))

    %{
      "id" => product["id"],
      "title" => product["title"],
      "handle" => product["handle"],
      "url" => product["onlineStoreUrl"],
      "variants" => variants,
      "purchasable_variants" => Enum.filter(variants, & &1["available"])
    }
  end

  defp variant(variant, context) do
    price = variant["price"]

    available =
      variant["availableForSale"] == true and
        (is_nil(variant["quantityAvailable"]) or variant["quantityAvailable"] > 0)

    %{
      "id" => variant["id"],
      "title" => variant["title"],
      "available" => available,
      "price" => price["amount"],
      "currency" => price["currencyCode"],
      "display_price" => Price.format(price["amount"], price["currencyCode"], context.locale)
    }
  end

  defp value(arguments, key, default),
    do: Map.get(arguments, key, Map.get(arguments, String.to_existing_atom(key), default))
end
