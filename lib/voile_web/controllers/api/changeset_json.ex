defmodule VoileWeb.Api.ChangesetJSON do
  def error(%Ecto.Changeset{} = changeset) do
    %{
      errors: %{
        message: "Validation failed",
        details: translate_errors(changeset)
      }
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
