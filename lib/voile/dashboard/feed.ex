defmodule Voile.Dashboard.Feed do
  @moduledoc """
  Context for the dashboard "Attention Required" feed.

  Aggregates the operational items staff need to act on first — overdue loans,
  reservations awaiting pickup, expiring memberships, and expired memberships —
  into the uniform `%{icon, tone, title, subtitle, meta, href}` shape consumed
  by the v2 `voile_activity_feed` component.

  All queries honor node scoping: when the given user has a `node_id`, results
  are restricted to that node; super admins (with `node_id == nil`) see
  everything.
  """

  use Gettext, backend: VoileWeb.Gettext

  import Ecto.Query

  alias Voile.Repo
  alias Voile.Schema.Accounts.User
  alias Voile.Schema.Library.{Reservation, Transaction}

  @doc """
  Builds the attention feed for the given user.

  Returns a list of maps shaped for `voile_activity_feed`, ordered so the most
  urgent items (overdue loans) appear first. Each category is capped so the
  feed never grows unbounded.
  """
  def attention_items(user) do
    overdue_items(user)
    |> Kernel.++(pickup_items(user))
    |> Kernel.++(membership_items(user))
  end

  # ---------------------------------------------------------------------------
  # Overdue loans — specific transactions with member + collection title
  # ---------------------------------------------------------------------------

  defp overdue_items(user) do
    today = Date.utc_today()

    Transaction
    |> where([t], t.status == "overdue" and is_nil(t.return_date))
    |> join(:inner, [t], m in assoc(t, :member))
    |> join(:inner, [t, m], i in assoc(t, :item))
    |> join(:inner, [t, m, i], c in assoc(i, :collection))
    |> maybe_filter_transactions_by_node(user)
    |> order_by([t], asc: t.due_date)
    |> limit(5)
    |> select([t, m, i, c], %{
      id: t.id,
      due_date: t.due_date,
      member_name: m.fullname,
      collection_title: c.title
    })
    |> Repo.all()
    |> Enum.map(fn row ->
      days = max(Date.diff(today, DateTime.to_date(row.due_date)), 1)

      %{
        icon: "hero-exclamation-triangle",
        tone: :error,
        title: row.collection_title,
        subtitle: gettext("%{member} · overdue %{n} days", %{member: row.member_name, n: days}),
        meta: nil,
        href: "/manage/glam/library/circulation"
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Reservations ready for pickup — count-based summary
  # ---------------------------------------------------------------------------

  defp pickup_items(user) do
    count =
      Reservation
      |> where([r], r.status == "available")
      |> maybe_filter_reservations_by_node(user)
      |> Repo.aggregate(:count, :id)

    if count > 0 do
      [
        %{
          icon: "hero-bookmark",
          tone: :warning,
          title: gettext("%{count} reservations ready for pickup", %{count: count}),
          subtitle: gettext("Notify members or release the hold"),
          meta: nil,
          href: "/manage/glam/library/circulation"
        }
      ]
    else
      []
    end
  end

  # ---------------------------------------------------------------------------
  # Memberships — expiring soon + already expired, count-based summaries
  # ---------------------------------------------------------------------------

  defp membership_items(user) do
    thirty_days = Date.add(Date.utc_today(), 30)

    expiring =
      User
      |> where(
        [u],
        not is_nil(u.expiry_date) and u.expiry_date <= ^thirty_days and
          u.expiry_date >= ^Date.utc_today()
      )
      |> maybe_filter_users_by_node(user)
      |> Repo.aggregate(:count, :id)

    expired =
      User
      |> where([u], not is_nil(u.expiry_date) and u.expiry_date < ^Date.utc_today())
      |> maybe_filter_users_by_node(user)
      |> Repo.aggregate(:count, :id)

    expiring_item(expiring) ++ expired_item(expired)
  end

  defp expiring_item(0), do: []

  defp expiring_item(count) do
    [
      %{
        icon: "hero-clock",
        tone: :warning,
        title: gettext("%{count} memberships expire within 30 days", %{count: count}),
        subtitle: gettext("Reach out before they lapse"),
        meta: nil,
        href: "/manage/members/management"
      }
    ]
  end

  defp expired_item(0), do: []

  defp expired_item(count) do
    [
      %{
        icon: "hero-user-minus",
        tone: :error,
        title: gettext("%{count} memberships have expired", %{count: count}),
        subtitle: gettext("Review and renew where appropriate"),
        meta: nil,
        href: "/manage/members/management"
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Node scoping
  # ---------------------------------------------------------------------------

  defp maybe_filter_transactions_by_node(q, %{node_id: nil}), do: q

  defp maybe_filter_transactions_by_node(q, %{node_id: node_id}) do
    where(q, [t], t.unit_id == ^node_id or is_nil(t.unit_id))
  end

  defp maybe_filter_reservations_by_node(q, %{node_id: nil}), do: q

  defp maybe_filter_reservations_by_node(q, %{node_id: node_id}) do
    from(r in q,
      join: c in assoc(r, :collection),
      where: c.unit_id == ^node_id or is_nil(c.unit_id)
    )
  end

  defp maybe_filter_users_by_node(q, %{node_id: nil}), do: q

  defp maybe_filter_users_by_node(q, %{node_id: node_id}) do
    where(q, [u], u.node_id == ^node_id)
  end
end
