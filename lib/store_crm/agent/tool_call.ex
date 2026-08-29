defmodule StoreCRM.Agent.ToolCall do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tool_calls" do
    field :name, :string
    field :arguments, :map
    field :result, :map
    field :status, :string
    field :duration_ms, :integer, default: 0
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :agent_run, StoreCRM.Agent.AgentRun
    timestamps(type: :utc_datetime)
  end

  def changeset(call, attrs),
    do:
      call
      |> cast(attrs, [:name, :arguments, :result, :status, :duration_ms])
      |> validate_required([:name, :arguments, :status])
end
