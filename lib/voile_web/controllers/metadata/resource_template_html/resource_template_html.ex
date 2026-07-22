defmodule VoileWeb.ResourceTemplateHTML do
  use VoileWeb, :html

  import VoileWeb.DashboardComponents

  embed_templates "*"

  @doc """
  Renders a resource_template form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def resource_template_form(assigns)
end
