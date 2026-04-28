defmodule Voile.Factory do
  @moduledoc """
  Test factory helpers for the Voile test suite.
  """

  alias Voile.Repo
  alias Voile.Schema.Catalog.Attachment

  import Voile.AccountsFixtures
  import Voile.CatalogFixtures
  import Voile.MetadataFixtures
  import Voile.SystemFixtures

  def insert(name, attrs \\ %{})
  def insert(:user, attrs), do: user_fixture(attrs)
  def insert(:role, attrs), do: role_fixture(attrs)
  def insert(:user_role_assignment, attrs), do: user_role_assignment_fixture(attrs)
  def insert(:node, attrs), do: node_fixture(attrs)
  def insert(:resource_class, attrs), do: resource_class_fixture(attrs)
  def insert(:collection, attrs), do: collection_fixture(attrs)
  def insert(:item, attrs), do: item_fixture(attrs)
  def insert(:attachment, attrs), do: attachment_fixture(attrs)

  def insert_list(count, name, attrs \\ %{}) when is_integer(count) and count > 0 do
    for _ <- 1..count, do: insert(name, attrs)
  end

  defp attachment_fixture(attrs) do
    attrs =
      attrs
      |> Enum.into(%{
        file_name: "upload.txt",
        original_name: "upload.txt",
        file_path: "/uploads/attachments/upload.txt",
        file_key: "uploads/attachments/upload.txt",
        file_size: 123,
        mime_type: "text/plain",
        file_type: "document",
        description: "Test attachment",
        access_level: "public",
        attachable_type: "collection",
        attachable_id: Ecto.UUID.generate(),
        sort_order: 0,
        is_primary: false,
        metadata: %{}
      })

    %Attachment{}
    |> Attachment.changeset(attrs)
    |> Repo.insert!()
  end
end
