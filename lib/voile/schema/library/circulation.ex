defmodule Voile.Schema.Library.Circulation do
  import Ecto.Query
  alias Voile.Repo
  alias Voile.Schema.Accounts
  alias Voile.Schema.Catalog
  alias Voile.Schema.Accounts.{User, UserRole}
  alias Voile.Schema.Catalog.{Collection, Item}
  alias Voile.Schema.Library.{CirculationHistory, Fine, Requisition, Reservation, Transaction}

  # Circulation History Context
  def list_circulation_history do
    Repo.all(CirculationHistory)
  end

  def list_circulation_history_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from ch in CirculationHistory,
        preload: [
          :member,
          :item,
          :transaction,
          :reservation,
          :fine,
          :processed_by,
          :waived_by
        ],
        order_by: [desc: ch.inserted_at, desc: ch.id],
        offset: ^offset,
        limit: ^per_page

    circulation_history = Repo.all(query)

    total_count = Repo.aggregate(CirculationHistory, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {circulation_history, total_pages}
  end

  def get_circulation_history(id) do
    CirculationHistory
    |> Repo.get(id)
    |> Repo.preload([
      :member,
      :item,
      :transaction,
      :reservation,
      :fine,
      :processed_by,
      :waived_by
    ])
  end

  def create_circulation_history(attrs \\ %{}) do
    %CirculationHistory{}
    |> CirculationHistory.changeset(attrs)
    |> Repo.insert()
  end

  def update_circulation_history(%CirculationHistory{} = circulation_history, attrs) do
    circulation_history
    |> CirculationHistory.changeset(attrs)
    |> Repo.update()
  end

  def delete_circulation_history(%CirculationHistory{} = circulation_history) do
    Repo.delete(circulation_history)
  end

  def change_circulation_history(%CirculationHistory{} = circulation_history, attrs) do
    circulation_history
    |> Repo.preload([
      :member,
      :item,
      :transaction,
      :reservation,
      :fine,
      :processed_by,
      :waived_by
    ])
    |> CirculationHistory.changeset(attrs)
  end

  # Circulation Fines Context
  def list_fines do
    Repo.all(Fine)
  end

  def list_fines_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from f in Fine,
        preload: [
          :member,
          :item,
          :transaction,
          :processed_by,
          :waived_by
        ],
        order_by: [desc: f.inserted_at, desc: f.id],
        offset: ^offset,
        limit: ^per_page

    fines = Repo.all(query)

    total_count = Repo.aggregate(Fine, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {fines, total_pages}
  end

  def get_fine!(id) do
    Fine
    |> Repo.get!(id)
    |> Repo.preload([
      :member,
      :item,
      :transaction,
      :processed_by,
      :waived_by
    ])
  end

  def create_fines(attrs \\ %{}) do
    %Fine{}
    |> Fine.changeset(attrs)
    |> Repo.insert()
  end

  def update_fine(%Fine{} = fine, attrs) do
    fine
    |> Fine.changeset(attrs)
    |> Repo.update()
  end

  def delete_fine(%Fine{} = fine) do
    Repo.delete(fine)
  end

  def change_fine(%Fine{} = fine, attrs) do
    fine
    |> Repo.preload([
      :member,
      :item,
      :transaction,
      :processed_by,
      :waived_by
    ])
    |> Fine.changeset(attrs)
  end

  def list_requisitions do
    Repo.all(Requisition)
  end

  def list_requisitions_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from r in Requisition,
        preload: [:requested_by, :assigned_to, :unit],
        order_by: [desc: r.inserted_at, desc: r.id],
        offset: ^offset,
        limit: ^per_page

    requisitions = Repo.all(query)

    total_count = Repo.aggregate(Requisition, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {requisitions, total_pages}
  end

  def get_requisition!(id) do
    Requisition
    |> Repo.get!(id)
    |> Repo.preload([
      :requested_by,
      :assigned_to,
      :unit
    ])
  end

  def create_requisition(attrs \\ %{}) do
    %Requisition{}
    |> Requisition.changeset(attrs)
    |> Repo.insert()
  end

  def update_requisition(%Requisition{} = requisition, attrs) do
    requisition
    |> Requisition.changeset(attrs)
    |> Repo.update()
  end

  def delete_requisition(%Requisition{} = requisition) do
    Repo.delete(requisition)
  end

  def change_requisition(%Requisition{} = requisition, attrs) do
    requisition
    |> Repo.preload([
      :requested_by,
      :assigned_to,
      :unit
    ])
    |> Requisition.changeset(attrs)
  end

  def list_reservations do
    Repo.all(Reservation)
  end

  def list_reservations_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from r in Reservation,
        preload: [
          :item,
          :member,
          :collection,
          :processed_by
        ],
        order_by: [desc: r.inserted_at, desc: r.id],
        offset: ^offset,
        limit: ^per_page

    reservations = Repo.all(query)

    total_count = Repo.aggregate(Reservation, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {reservations, total_pages}
  end

  def get_reservation!(id) do
    Reservation
    |> Repo.get!(id)
    |> Repo.preload([
      :member,
      :item,
      :collection,
      :processed_by
    ])
  end

  def create_reservation(attrs \\ %{}) do
    %Reservation{}
    |> Reservation.changeset(attrs)
    |> Repo.insert()
  end

  def update_reservation(%Reservation{} = reservation, attrs) do
    reservation
    |> Reservation.changeset(attrs)
    |> Repo.update()
  end

  def delete_reservation(%Reservation{} = reservation) do
    Repo.delete(reservation)
  end

  def change_reservation(%Reservation{} = reservation, attrs) do
    reservation
    |> Repo.preload([
      :member,
      :item,
      :collection,
      :processed_by
    ])
    |> Reservation.changeset(attrs)
  end

  def list_transactions do
    Repo.all(Transaction)
  end

  def list_transactions_paginated(page \\ 1, per_page \\ 10) do
    offset = (page - 1) * per_page

    query =
      from t in Transaction,
        preload: [
          :item,
          :member,
          :librarian
        ],
        order_by: [desc: t.inserted_at, desc: t.id],
        offset: ^offset,
        limit: ^per_page

    transactions = Repo.all(query)

    total_count = Repo.aggregate(Transaction, :count, :id)
    total_pages = div(total_count + per_page - 1, per_page)

    {transactions, total_pages}
  end

  def get_transaction!(id) do
    Transaction
    |> Repo.get!(id)
    |> Repo.preload([
      :item,
      :member,
      :librarian
    ])
  end

  def create_transaction(attrs \\ %{}) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
  end

  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
  end

  def change_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Repo.preload([
      :item,
      :member,
      :librarian
    ])
    |> Transaction.changeset(attrs)
  end
end
