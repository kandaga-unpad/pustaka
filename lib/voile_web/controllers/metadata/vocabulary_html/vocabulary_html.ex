defmodule VoileWeb.VocabularyHTML do
  use VoileWeb, :html

  import VoileWeb.DashboardComponents

  embed_templates "*"

  @doc """
  Renders a vocabulary form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def vocabulary_form(assigns)
end
