# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     StoreCRM.Repo.insert!(%StoreCRM.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias StoreCRM.Repo
alias StoreCRM.Stores
alias StoreCRM.Stores.StoreProfile

attrs = Stores.colombia_attrs()

case Repo.get_by(StoreProfile, slug: attrs.slug) do
  nil -> %StoreProfile{} |> StoreProfile.changeset(attrs) |> Repo.insert!()
  profile -> profile |> StoreProfile.changeset(attrs) |> Repo.update!()
end
