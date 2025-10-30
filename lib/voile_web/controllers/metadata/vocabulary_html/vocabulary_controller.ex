defmodule VoileWeb.VocabularyController do
  use VoileWeb, :controller_dashboard

  alias Voile.Schema.Metadata
  alias Voile.Schema.Metadata.Vocabulary

  plug VoileWeb.Plugs.Authorize,
    permissions: %{
      new: ["metadata.manage"],
      create: ["metadata.manage"],
      edit: ["metadata.manage", "metadata.edit"],
      update: ["metadata.manage", "metadata.edit"],
      delete: ["metadata.manage"]
    }

  def index(conn, _params) do
    metadata_vocabularies = Metadata.list_metadata_vocabularies()
    render(conn, :index, metadata_vocabularies: metadata_vocabularies)
  end

  def new(conn, _params) do
    changeset = Metadata.change_vocabulary(%Vocabulary{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"vocabulary" => vocabulary_params}) do
    case Metadata.create_vocabulary(vocabulary_params) do
      {:ok, vocabulary} ->
        conn
        |> put_flash(:info, "Vocabulary created successfully.")
        |> redirect(to: ~p"/manage/metaresource/metadata_vocabularies/#{vocabulary}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    vocabulary = Metadata.get_vocabulary!(id)
    render(conn, :show, vocabulary: vocabulary)
  end

  def edit(conn, %{"id" => id}) do
    vocabulary = Metadata.get_vocabulary!(id)
    changeset = Metadata.change_vocabulary(vocabulary)
    render(conn, :edit, vocabulary: vocabulary, changeset: changeset)
  end

  def update(conn, %{"id" => id, "vocabulary" => vocabulary_params}) do
    vocabulary = Metadata.get_vocabulary!(id)

    case Metadata.update_vocabulary(vocabulary, vocabulary_params) do
      {:ok, vocabulary} ->
        conn
        |> put_flash(:info, "Vocabulary updated successfully.")
        |> redirect(to: ~p"/manage/metaresource/metadata_vocabularies/#{vocabulary}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, vocabulary: vocabulary, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    vocabulary = Metadata.get_vocabulary!(id)
    {:ok, _vocabulary} = Metadata.delete_vocabulary(vocabulary)

    conn
    |> put_flash(:info, "Vocabulary deleted successfully.")
    |> redirect(to: ~p"/manage/metaresource/metadata_vocabularies")
  end
end
