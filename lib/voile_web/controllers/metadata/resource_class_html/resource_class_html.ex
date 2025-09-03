defmodule VoileWeb.ResourceClassHTML do
  use VoileWeb, :html

  embed_templates "*"

  @doc """
  Renders a resource_class form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil

  def resource_class_form(assigns)

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
