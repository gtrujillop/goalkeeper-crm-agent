defmodule StoreCRM.Stores do
  alias StoreCRM.Repo
  alias StoreCRM.Stores.StoreProfile

  def get_profile!(id), do: Repo.get!(StoreProfile, id)
  def get_profile_by_slug!(slug), do: Repo.get_by!(StoreProfile, slug: slug)
  def create_profile(attrs), do: %StoreProfile{} |> StoreProfile.changeset(attrs) |> Repo.insert()

  def colombia_attrs do
    %{
      slug: "colombia",
      name: "Goalkeeper Store Colombia",
      market: "CO",
      default_locale: "es-CO",
      currency: "COP",
      timezone: "America/Bogota",
      phone_region: "CO",
      enabled_locales: ["es-CO"],
      agent_limits: %{"max_tool_calls" => 3, "max_tokens" => 2_000}
    }
  end
end
