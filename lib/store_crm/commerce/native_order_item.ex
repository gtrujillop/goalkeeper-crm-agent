defmodule StoreCRM.Commerce.NativeOrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :title, :string
    field :variant, :string
    field :quantity, :integer, default: 1
    field :unit_price, :decimal
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:title, :variant, :quantity, :unit_price])
    |> validate_required([:title, :quantity, :unit_price])
    |> validate_length(:title, max: 200)
    |> validate_length(:variant, max: 100)
    |> validate_number(:quantity, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:unit_price,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1_000_000_000
    )
    |> validate_change(:unit_price, fn :unit_price, price ->
      if Decimal.equal?(price, Decimal.round(price, 2)),
        do: [],
        else: [unit_price: "Usa hasta dos decimales"]
    end)
  end
end
