defmodule VoileWeb.Utils.AuthHelper do
  @moduledoc """
  Helper functions for authorization in templates
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
  def role_badge_class(role_name) do
    case role_name do
      "Admin Node" -> "bg-voile-error text-voile-dark"
      "Administrator Dev" -> "bg-voile-primary text-voile-dark"
      "Koordinator Koleksi" -> "bg-voile-info text-voile-dark"
      "Pustakawan (Koordinator)" -> "bg-voile-success text-voile-dark"
      "Arsiparis (Koordinator)" -> "bg-voile-warning text-voile-dark"
      "Kurator Museum" -> "bg-voile-primary text-voile-dark"
      "Kurator Galeri" -> "bg-voile-accent text-voile-dark"
      _ -> "bg-voile-surface text-voile-dark"
    end
  end
end
