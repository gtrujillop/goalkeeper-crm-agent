defmodule StoreCRM.Conversations.Handoff do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "handoffs" do
    field :reason, :string
    field :summary, :string
    field :status, :string, default: "requested"
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    belongs_to :conversation, StoreCRM.Conversations.Conversation
    belongs_to :agent_run, StoreCRM.Agent.AgentRun
    timestamps(type: :utc_datetime)
  end

  def changeset(handoff, attrs),
    do:
      handoff
      |> cast(attrs, [:reason, :summary, :status])
      |> validate_required([:reason, :summary, :status])
end
