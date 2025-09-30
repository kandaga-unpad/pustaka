defmodule VoileWeb.Helpers.AuthHelper do
  @moduledoc """
  Helper functions for authorization in templates.
  """

  alias Voile.Schema.Accounts

  @doc """
  Checks if the current user has permission for a resource and action.
  """
  def can?(user, resource, action) do
    Accounts.has_permission?(user, resource, action)
  end

  @doc """
  Checks if the current user can access a resource.
  """
  def can_access?(user, resource) do
    Accounts.can_access_resource?(user, resource)
  end

  @doc """
  Returns CSS classes for permission-based styling.
  """
  def permission_class(
        user,
        resource,
        action,
        allowed_class \\ "",
        denied_class \\ "opacity-50 cursor-not-allowed"
      ) do
    if can?(user, resource, action) do
      allowed_class
    else
      denied_class
    end
  end

  @doc """
  Generates a list of available actions for a user on a resource.
  """
  def available_actions(user, resource) do
    actions = ["create", "read", "update", "delete"]

    Enum.filter(actions, fn action ->
      can?(user, resource, action)
    end)
  end

  @doc """
  Gets user role badge class based on role name.
  """
  def role_badge_class(nil), do: "bg-gray-100 text-gray-800"

  def role_badge_class(role_name) do
    rn = role_name |> to_string() |> String.trim() |> String.downcase()

    cond do
      # Admin node (high-privilege, node-specific admin)
      String.contains?(rn, "admin node") or String.contains?(rn, "node admin") ->
        "bg-red-100 text-red-800"

      # Super / Developer administrators
      rn in ["administrator dev", "super administrator dev"] or
          (String.contains?(rn, "administrator") and String.contains?(rn, "dev")) ->
        "bg-purple-100 text-purple-800"

      # Generic admin (fall back to purple-ish admin style)
      String.contains?(rn, "administrator") or String.contains?(rn, "admin") ->
        "bg-purple-50 text-purple-800"

      # Coordinators
      String.contains?(rn, "koordinator") or String.contains?(rn, "coordinator") ->
        "bg-blue-100 text-blue-800"

      # Librarians / Pustakawan
      String.contains?(rn, "pustakawan") or String.contains?(rn, "librarian") ->
        "bg-green-100 text-green-800"

      # Archivists
      String.contains?(rn, "arsiparis") or String.contains?(rn, "archivist") ->
        "bg-yellow-100 text-yellow-800"

      # Curators
      String.contains?(rn, "kurator") or String.contains?(rn, "curator") ->
        "bg-indigo-100 text-indigo-800"

      # Gallery-specific roles
      String.contains?(rn, "galeri") or String.contains?(rn, "gallery") ->
        "bg-pink-100 text-pink-800"

      # Developers / engineers
      String.contains?(rn, "dev") or String.contains?(rn, "developer") ->
        "bg-purple-50 text-purple-700"

      # Members / default users
      String.contains?(rn, "member") or String.contains?(rn, "user") ->
        "bg-gray-50 text-gray-700"

      # Fallback
      true ->
        "bg-gray-100 text-gray-800"
    end
  end
end
