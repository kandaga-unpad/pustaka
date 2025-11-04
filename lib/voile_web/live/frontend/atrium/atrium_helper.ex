defmodule VoileWeb.Frontend.Atrium.AtriumHelper do
  @moduledoc """
  Helper functions for the Atrium (member self-service portal).

  This module contains utility functions for:
  - Transaction renewal validation
  - Association data extraction (roles, user types, nodes)
  - Date calculations
  - URL utilities
  """

  alias Voile.Schema.Library.Circulation

  @doc """
  Performs pre-checks before allowing a transaction renewal.

  Validates:
  - Member type allows renewals
  - Maximum renewals not exceeded
  - Renewal window (3 days before due to 1 day before due)

  Returns `{:ok}` if renewal is allowed, or `{:error, message}` otherwise.
  """
  def can_renew_transaction_precheck(_transaction_id, _member, nil) do
    # If we don't have the member type preloaded on the user, let server do
    # authoritative checks.
    {:ok}
  end

  def can_renew_transaction_precheck(transaction_id, _member, %{} = user_type) do
    # First check if member type allows renewals
    if not Map.get(user_type, :can_renew, true) do
      {:error, "Your member type does not allow renewing items"}
    else
      # Try to fetch transaction quickly and check renewal_count vs max_renewals.
      case Circulation.get_transaction(transaction_id) do
        nil ->
          # Let server-side handle missing transaction
          {:ok}

        tx ->
          max_renewals = Map.get(user_type, :max_renewals, 0) || 0

          if tx.renewal_count >= max_renewals do
            {:error, "Maximum renewals (#{max_renewals}) reached for your member type"}
          else
            # Check renewal window: 3 days before due to 1 day before due
            if tx.due_date do
              days_until_due = Date.diff(tx.due_date, Date.utc_today())

              cond do
                days_until_due <= 1 ->
                  {:error,
                   "Too late to renew. Items must be renewed at least 1 day before due date"}

                days_until_due > 3 ->
                  {:error,
                   "Too early to renew. You can renew starting 3 days before the due date"}

                true ->
                  {:ok}
              end
            else
              {:ok}
            end
          end
      end
    end
  end

  @doc """
  Extracts the role name from a user struct.

  Prefers loaded `roles` association, then `user_role_assignments`,
  or returns "-" if nothing is available.
  """
  def role_name(%{roles: [%{name: name} | _]}), do: to_string(name)

  def role_name(%{user_role_assignments: [%{role: %{name: name}} | _]}), do: to_string(name)

  def role_name(_), do: "-"

  @doc """
  Extracts the user type name from a user struct.

  Prefers loaded `user_type` struct, then `user_type_id`, or returns "-".
  """
  def user_type_name(%{user_type: %{name: name}}), do: name
  def user_type_name(%{user_type_id: id}) when not is_nil(id), do: to_string(id)
  def user_type_name(_), do: "-"

  @doc """
  Extracts the node name from a user struct.

  Prefers loaded `node` struct, then `node_id`, or returns "-".
  """
  def node_name(%{node: %{name: name}}), do: name
  def node_name(%{node_id: id}) when not is_nil(id), do: to_string(id)
  def node_name(_), do: "-"

  @doc """
  Adds a cache-busting timestamp parameter to a URL.

  This prevents browser caching of dynamic resources like user images.
  """
  def cache_bust(url) do
    ts = System.system_time(:millisecond)

    if String.contains?(url, "?"),
      do: url <> "&t=" <> Integer.to_string(ts),
      else: url <> "?t=" <> Integer.to_string(ts)
  end

  @doc """
  Calculates the new due date after renewal based on member type.

  Defaults to 21 days if member type doesn't specify max_days.
  """
  def calculate_new_due_date(current_due_date, member) do
    max_days =
      if member.user_type && member.user_type.max_days do
        member.user_type.max_days
      else
        21
      end

    Date.add(current_due_date, max_days)
  end
end
