defmodule Voile.Schema.Catalog.CollectionSchemaTest do
  use ExUnit.Case, async: true

  alias Voile.Schema.Catalog.Collection

  describe "root_collection?/1" do
    test "returns true when collection has no parent" do
      collection = %Collection{parent_id: nil}
      assert Collection.root_collection?(collection)
    end

    test "returns false when collection has a parent" do
      collection = %Collection{parent_id: "some-parent-uuid"}
      refute Collection.root_collection?(collection)
    end
  end

  describe "child_collection?/1" do
    test "returns true when collection has a parent" do
      collection = %Collection{parent_id: "some-parent-uuid"}
      assert Collection.child_collection?(collection)
    end

    test "returns false when collection has no parent" do
      collection = %Collection{parent_id: nil}
      refute Collection.child_collection?(collection)
    end
  end

  describe "collection_type_options/0" do
    test "returns a list of {label, value} tuples" do
      options = Collection.collection_type_options()

      assert is_list(options)
      assert length(options) > 0

      Enum.each(options, fn {label, value} ->
        assert is_binary(label)
        assert is_binary(value)
      end)
    end

    test "includes expected collection types" do
      options = Collection.collection_type_options()
      values = Enum.map(options, fn {_label, val} -> val end)

      assert "book" in values
      assert "series" in values
      assert "movie" in values
      assert "album" in values
      assert "course" in values
      assert "other" in values
    end

    test "labels are human-readable strings" do
      options = Collection.collection_type_options()
      labels = Enum.map(options, fn {label, _val} -> label end)

      assert "Book" in labels
      assert "Series" in labels
      assert "Movie" in labels
    end
  end

  describe "attachments_by_type/2" do
    test "filters collection attachments by file_type" do
      attachments = [
        %{file_type: "pdf", name: "manifest.pdf"},
        %{file_type: "image", name: "cover.jpg"},
        %{file_type: "pdf", name: "index.pdf"}
      ]

      collection = %Collection{attachments: attachments}
      pdf_attachments = Collection.attachments_by_type(collection, "pdf")

      assert length(pdf_attachments) == 2
      assert Enum.all?(pdf_attachments, fn a -> a.file_type == "pdf" end)
    end

    test "returns empty list when no matching attachments" do
      collection = %Collection{attachments: [%{file_type: "image", name: "cover.jpg"}]}
      assert Collection.attachments_by_type(collection, "pdf") == []
    end

    test "returns empty list when attachments is empty" do
      collection = %Collection{attachments: []}
      assert Collection.attachments_by_type(collection, "pdf") == []
    end
  end

  describe "primary_attachment/1" do
    test "returns the primary attachment" do
      attachments = [
        %{is_primary: false, name: "cover.jpg"},
        %{is_primary: true, name: "primary.jpg"},
        %{is_primary: false, name: "other.jpg"}
      ]

      collection = %Collection{attachments: attachments}
      primary = Collection.primary_attachment(collection)

      assert primary.name == "primary.jpg"
      assert primary.is_primary == true
    end

    test "returns nil when no primary attachment" do
      attachments = [
        %{is_primary: false, name: "cover.jpg"}
      ]

      collection = %Collection{attachments: attachments}
      assert Collection.primary_attachment(collection) == nil
    end

    test "returns nil when attachments list is empty" do
      collection = %Collection{attachments: []}
      assert Collection.primary_attachment(collection) == nil
    end
  end

  describe "changeset/2 - validation" do
    test "changeset validates status inclusion" do
      changeset =
        Collection.changeset(%Collection{}, %{
          title: "Test",
          description: "Test desc",
          status: "invalid_status",
          access_level: "public",
          creator_id: 1,
          type_id: 1,
          thumbnail: "thumb.jpg"
        })

      refute changeset.valid?
      assert "Status tidak valid" in errors_on(changeset).status
    end

    test "changeset accepts valid statuses" do
      valid_statuses = ~w(draft pending published archived)

      Enum.each(valid_statuses, fn status ->
        changeset =
          Collection.changeset(%Collection{}, %{
            title: "Test",
            description: "Test desc",
            status: status,
            access_level: "public",
            creator_id: 1,
            type_id: 1,
            thumbnail: "thumb.jpg"
          })

        # Should not have status errors
        errors = errors_on(changeset)
        refute Map.has_key?(errors, :status), "Expected no status error for: #{status}"
      end)
    end

    test "changeset validates access_level inclusion" do
      changeset =
        Collection.changeset(%Collection{}, %{
          title: "Test",
          description: "Test desc",
          status: "draft",
          access_level: "invalid_level",
          creator_id: 1,
          type_id: 1,
          thumbnail: "thumb.jpg"
        })

      refute changeset.valid?
      assert "Access level tidak valid" in errors_on(changeset).access_level
    end

    test "changeset accepts valid access levels" do
      valid_levels = ~w(public private restricted)

      Enum.each(valid_levels, fn access_level ->
        changeset =
          Collection.changeset(%Collection{}, %{
            title: "Test",
            description: "Test desc",
            status: "draft",
            access_level: access_level,
            creator_id: 1,
            type_id: 1,
            thumbnail: "thumb.jpg"
          })

        errors = errors_on(changeset)
        refute Map.has_key?(errors, :access_level),
               "Expected no access_level error for: #{access_level}"
      end)
    end

    test "changeset requires title" do
      changeset =
        Collection.changeset(%Collection{}, %{
          description: "Test desc",
          status: "draft",
          access_level: "public",
          creator_id: 1,
          type_id: 1,
          thumbnail: "thumb.jpg"
        })

      refute changeset.valid?
      assert "This field is required" in errors_on(changeset).title
    end

    test "changeset requires description" do
      changeset =
        Collection.changeset(%Collection{}, %{
          title: "Test",
          status: "draft",
          access_level: "public",
          creator_id: 1,
          type_id: 1,
          thumbnail: "thumb.jpg"
        })

      refute changeset.valid?
      assert "This field is required" in errors_on(changeset).description
    end

    test "changeset prevents parent_id equal to collection's own id" do
      collection_id = Ecto.UUID.generate()

      changeset =
        Collection.changeset(%Collection{id: collection_id}, %{
          id: collection_id,
          title: "Test",
          description: "Test desc",
          status: "draft",
          access_level: "public",
          creator_id: 1,
          type_id: 1,
          thumbnail: "thumb.jpg",
          parent_id: collection_id
        })

      refute changeset.valid?
      assert "cannot be the same as the collection itself" in errors_on(changeset).parent_id
    end

    test "changeset allows valid collection_code within length limit" do
      changeset =
        Collection.changeset(%Collection{}, %{
          title: "Test",
          description: "Test desc",
          status: "draft",
          access_level: "public",
          creator_id: 1,
          type_id: 1,
          thumbnail: "thumb.jpg",
          collection_code: "CODE-001"
        })

      errors = errors_on(changeset)
      refute Map.has_key?(errors, :collection_code)
    end

    test "changeset rejects collection_code exceeding 255 characters" do
      long_code = String.duplicate("a", 256)

      changeset =
        Collection.changeset(%Collection{}, %{
          title: "Test",
          description: "Test desc",
          status: "draft",
          access_level: "public",
          creator_id: 1,
          type_id: 1,
          thumbnail: "thumb.jpg",
          collection_code: long_code
        })

      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).collection_code
    end
  end

  describe "remove_thumbnail_changeset/1" do
    test "sets thumbnail to nil" do
      collection = %Collection{thumbnail: "some-thumbnail.jpg"}
      changeset = Collection.remove_thumbnail_changeset(collection)

      assert Ecto.Changeset.get_field(changeset, :thumbnail) == nil
    end
  end

  # Helper to format changeset errors (mirrors DataCase.errors_on/1)
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
