defmodule VoileWeb.PropertyHTML do
  use VoileWeb, :html

  import VoileWeb.DashboardComponents

  embed_templates "*"

  @doc """
  Renders a property form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :vocabulary_list, :list
  attr :action, :string, required: true
  attr :current_user, :map

  def property_form(assigns)

  def trim_information(information, number) do
    cond do
      is_nil(information) ->
        nil

      String.length(information) <= number ->
        information

      true ->
        String.slice(information, 0, number) <> "..."
    end
  end
end
