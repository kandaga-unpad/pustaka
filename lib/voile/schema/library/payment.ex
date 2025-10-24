defmodule Voile.Schema.Library.Payment do
  @moduledoc """
  Schema for library fine payments via payment gateway (Xendit).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.Fine

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "lib_payments" do
    field :payment_gateway, :string, default: "xendit"
    field :payment_link_id, :string
    field :external_id, :string
    field :payment_url, :string

    field :amount, :decimal
    field :paid_amount, :decimal, default: Decimal.new("0")
    field :currency, :string, default: "IDR"
    field :payment_method, :string
    field :payment_channel, :string

    field :status, :string, default: "pending"
    field :payment_date, :utc_datetime
    field :expired_at, :utc_datetime
    field :failure_reason, :string

    field :description, :string
    field :callback_data, :map
    field :metadata, :map

    belongs_to :fine, Fine, type: :binary_id
    belongs_to :member, User, foreign_key: :member_id, type: :binary_id
    belongs_to :processed_by, User, foreign_key: :processed_by_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @payment_gateways ~w(xendit manual)
  @statuses ~w(pending paid failed expired cancelled)

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :fine_id,
      :member_id,
      :payment_gateway,
      :payment_link_id,
      :external_id,
      :payment_url,
      :amount,
      :paid_amount,
      :currency,
      :payment_method,
      :payment_channel,
      :status,
      :payment_date,
      :expired_at,
      :failure_reason,
      :description,
      :callback_data,
      :metadata,
      :processed_by_id
    ])
    |> validate_required([:member_id, :payment_gateway, :external_id, :amount, :status])
    |> validate_inclusion(:payment_gateway, @payment_gateways)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:paid_amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:fine_id)
    |> foreign_key_constraint(:member_id)
    |> foreign_key_constraint(:processed_by_id)
    |> unique_constraint(:external_id)
  end

  @doc """
  Changeset for updating payment status from webhook callbacks.
  """
  def webhook_changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :status,
      :paid_amount,
      :payment_date,
      :payment_method,
      :payment_channel,
      :failure_reason,
      :callback_data
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end

  def paid?(%__MODULE__{status: "paid"}), do: true
  def paid?(_), do: false

  def pending?(%__MODULE__{status: "pending"}), do: true
  def pending?(_), do: false

  def failed?(%__MODULE__{status: status}) when status in ["failed", "expired", "cancelled"],
    do: true

  def failed?(_), do: false
end
