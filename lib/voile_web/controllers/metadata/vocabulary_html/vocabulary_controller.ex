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

  defp breadcrumb(last) do
    [
      %{label: gettext("Manage"), path: "/manage"},
      %{label: gettext("Metaresource"), path: "/manage/metaresource"},
      %{label: gettext("Vocabulary"), path: "/manage/metaresource/metadata_vocabularies"},
      %{label: last, path: nil}
    ]
  end

  def index(conn, params) do
    page = Voile.Utils.Pagination.parse_page(Map.get(params, "page"))
    per_page = 10

    {metadata_vocabularies, total_pages, _} =
      Metadata.list_metadata_page(:vocabulary, page, per_page)

    conn
    |> assign(:breadcrumb, breadcrumb(gettext("All")))
    |> assign(:metadata_vocabularies, metadata_vocabularies)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> render(:index)
  end

  def new(conn, _params) do
    changeset = Metadata.change_vocabulary(%Vocabulary{})

    conn
    |> assign(:breadcrumb, breadcrumb(gettext("New")))
    |> assign(:changeset, changeset)
    |> render(:new)
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

    conn
    |> assign(:breadcrumb, breadcrumb(gettext("Show")))
    |> assign(:vocabulary, vocabulary)
    |> render(:show)
  end

  def edit(conn, %{"id" => id}) do
    vocabulary = Metadata.get_vocabulary!(id)
    changeset = Metadata.change_vocabulary(vocabulary)

    conn
    |> assign(:breadcrumb, breadcrumb(gettext("Edit")))
    |> assign(:vocabulary, vocabulary)
    |> assign(:changeset, changeset)
    |> render(:edit)
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
