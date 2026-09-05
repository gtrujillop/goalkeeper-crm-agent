defmodule StoreCRM.CRM.FollowUpTask do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "follow_up_tasks" do
    field :title, :string
    field :due_at, :utc_datetime
    field :status, :string, default: "open"
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    belongs_to :conversation, StoreCRM.Conversations.Conversation
    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs),
    do:
      task
      |> cast(attrs, [:title, :due_at, :status])
      |> validate_required([:title, :status])
      |> validate_inclusion(:status, ~w(open done))
end
