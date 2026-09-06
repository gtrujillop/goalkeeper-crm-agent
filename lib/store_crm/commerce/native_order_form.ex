defmodule StoreCRM.Commerce.NativeOrderForm do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key false
  embedded_schema do
    field :recipient, :string
    field :phone, :string
    field :address, :string
    field :city, :string
    field :carrier, :string
    field :payment_path, :string, default: "collect_on_delivery"
    field :shipping_cost, :decimal, default: Decimal.new(0)
    field :notes, :string
    field :opportunity_id, :binary_id
    embeds_many :items, StoreCRM.Commerce.NativeOrderItem, on_replace: :delete
  end

  def changeset(form, attrs) do
    form
    |> cast(attrs, [
      :recipient,
      :phone,
      :address,
      :city,
      :carrier,
      :payment_path,
      :shipping_cost,
      :notes,
      :opportunity_id
    ])
    |> validate_required([:recipient, :phone, :address, :city, :payment_path, :shipping_cost])
    |> validate_inclusion(:payment_path, ~w(bank_transfer collect_on_delivery))
    |> validate_length(:recipient, max: 200)
    |> validate_length(:phone, max: 30)
    |> validate_length(:address, max: 500)
    |> validate_length(:city, max: 100)
    |> validate_length(:carrier, max: 100)
    |> validate_length(:notes, max: 2000)
    |> validate_number(:shipping_cost,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 1_000_000_000
    )
    |> validate_change(:shipping_cost, fn :shipping_cost, price ->
      if Decimal.equal?(price, Decimal.round(price, 2)),
        do: [],
        else: [shipping_cost: "Usa hasta dos decimales"]
    end)
    |> cast_embed(:items, required: true)
    |> validate_length(:items, min: 1, max: 20)
  end
end
