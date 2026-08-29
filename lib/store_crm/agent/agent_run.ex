defmodule StoreCRM.Agent.AgentRun do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_runs" do
    field :prompt_version, :string
    field :prompt, :string
    field :provider, :string
    field :model, :string
    field :provider_request_id, :string
    field :context, :map
    field :result, :string
    field :outcome, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :estimated_cost, :decimal, default: Decimal.new(0)
    field :iteration_count, :integer, default: 0
    field :error, :string
    belongs_to :store_profile, StoreCRM.Stores.StoreProfile
    belongs_to :customer, StoreCRM.Customers.Customer
    belongs_to :conversation, StoreCRM.Conversations.Conversation
    belongs_to :input_message, StoreCRM.Conversations.Message
    belongs_to :output_message, StoreCRM.Conversations.Message
    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs),
    do:
      run
      |> cast(attrs, [
        :prompt_version,
        :prompt,
        :provider,
        :model,
        :provider_request_id,
        :context,
        :result,
        :outcome,
        :input_tokens,
        :output_tokens,
        :estimated_cost,
        :iteration_count,
        :error,
        :output_message_id
      ])
      |> validate_required([:prompt_version, :prompt, :provider, :model, :context, :outcome])
end
