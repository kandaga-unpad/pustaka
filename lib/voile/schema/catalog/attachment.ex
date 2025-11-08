defmodule Voile.Schema.Catalog.Attachment do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "attachments" do
    field :file_name, :string
    field :original_name, :string
    field :file_path, :string
    field :file_size, :integer
    field :mime_type, :string
    field :file_type, :string
    field :description, :string
    field :sort_order, :integer, default: 0
    field :is_primary, :boolean, default: false
    field :metadata, :map, default: %{}

    # Polymorphic associations
    field :attachable_id, :binary_id
    field :attachable_type, :string
    # Virtual field to hold the loaded polymorphic entity (collection or item)
    field :attachable, :any, virtual: true

    # Access control
    field :access_level, :string, default: "public"
    field :embargo_start_date, :utc_datetime
    field :embargo_end_date, :utc_datetime

    # Audit fields for access settings
    belongs_to :access_settings_updated_by, Voile.Schema.Accounts.User, type: :binary_id
    field :access_settings_updated_at, :utc_datetime

    # Access control relationships
    has_many :attachment_role_accesses, Voile.Schema.Catalog.AttachmentRoleAccess
    has_many :allowed_roles, through: [:attachment_role_accesses, :role]
    has_many :attachment_user_accesses, Voile.Schema.Catalog.AttachmentUserAccess
    has_many :allowed_users, through: [:attachment_user_accesses, :user]

    # Virtual field for file upload
    field :file, :any, virtual: true

    timestamps(type: :utc_datetime)
  end

  @file_types ~w(document image video audio software archive other)
  @attachable_types ~w(collection item)
  @access_levels ~w(public limited restricted)

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [
      :file_name,
      :original_name,
      :file_path,
      :file_size,
      :mime_type,
      :file_type,
      :description,
      :sort_order,
      :is_primary,
      :metadata,
      :attachable_id,
      :attachable_type,
      :access_level,
      :embargo_start_date,
      :embargo_end_date,
      :access_settings_updated_by_id,
      :access_settings_updated_at
    ])
    |> validate_required([
      :file_name,
      :original_name,
      :file_path,
      :file_size,
      :mime_type,
      :file_type,
      :attachable_id,
      :attachable_type
    ])
    |> validate_inclusion(:file_type, @file_types)
    |> validate_inclusion(:attachable_type, @attachable_types)
    |> validate_inclusion(:access_level, @access_levels)
    |> validate_number(:file_size, greater_than: 0)
    |> validate_number(:sort_order, greater_than_or_equal_to: 0)
    |> validate_embargo_dates()
    |> unique_constraint([:attachable_id, :attachable_type, :file_name],
      name: :attachments_unique_file_per_entity
    )
  end

  @doc """
  Changeset for updating access control settings.
  Automatically sets the audit fields.
  """
  def access_control_changeset(attachment, attrs, updated_by_user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attachment
    |> cast(attrs, [
      :access_level,
      :embargo_start_date,
      :embargo_end_date
    ])
    |> validate_required([:access_level])
    |> validate_inclusion(:access_level, @access_levels)
    |> validate_embargo_dates()
    |> put_change(:access_settings_updated_by_id, updated_by_user_id)
    |> put_change(:access_settings_updated_at, now)
  end

  defp validate_embargo_dates(changeset) do
    start_date = get_field(changeset, :embargo_start_date)
    end_date = get_field(changeset, :embargo_end_date)

    cond do
      is_nil(start_date) and is_nil(end_date) ->
        changeset

      is_nil(start_date) or is_nil(end_date) ->
        changeset

      DateTime.compare(start_date, end_date) in [:gt, :eq] ->
        add_error(changeset, :embargo_end_date, "must be after embargo start date")

      true ->
        changeset
    end
  end

  @doc """
  Determines file type based on mime type
  """
  def determine_file_type(mime_type) do
    case mime_type do
      "image/" <> _ -> "image"
      "video/" <> _ -> "video"
      "audio/" <> _ -> "audio"
      "application/pdf" -> "document"
      "application/msword" -> "document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "document"
      "application/vnd.ms-excel" -> "document"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "document"
      "application/zip" -> "archive"
      "application/x-rar-compressed" -> "archive"
      "application/x-7z-compressed" -> "archive"
      "application/octet-stream" -> "software"
      "application/x-executable" -> "software"
      "application/x-msdownload" -> "software"
      _ -> "other"
    end
  end

  @doc """
  Get attachments for a specific entity
  """
  def for_entity(query, entity_id, entity_type) do
    from a in query,
      where: a.attachable_id == ^entity_id and a.attachable_type == ^entity_type,
      order_by: [asc: a.sort_order, asc: a.inserted_at]
  end

  @doc """
  Get primary attachment for an entity
  """
  def primary_for_entity(query, entity_id, entity_type) do
    from a in query,
      where:
        a.attachable_id == ^entity_id and a.attachable_type == ^entity_type and
          a.is_primary == true,
      limit: 1
  end

  @doc """
  Get attachments by file type
  """
  def by_file_type(query, file_type) do
    from a in query, where: a.file_type == ^file_type
  end

  @doc """
  Get attachments by access level
  """
  def by_access_level(query, access_level) do
    from a in query, where: a.access_level == ^access_level
  end

  @doc """
  Get attachments that are currently under embargo
  """
  def under_embargo(query, current_datetime \\ nil) do
    now = current_datetime || DateTime.utc_now() |> DateTime.truncate(:second)

    from a in query,
      where:
        (not is_nil(a.embargo_start_date) and a.embargo_start_date > ^now) or
          (not is_nil(a.embargo_end_date) and a.embargo_end_date < ^now)
  end

  @doc """
  Get attachments that are accessible (not under embargo)
  """
  def not_under_embargo(query, current_datetime \\ nil) do
    now = current_datetime || DateTime.utc_now() |> DateTime.truncate(:second)

    from a in query,
      where:
        (is_nil(a.embargo_start_date) or a.embargo_start_date <= ^now) and
          (is_nil(a.embargo_end_date) or a.embargo_end_date >= ^now)
  end

  @doc """
  Preload access control associations
  """
  def with_access_control(query) do
    from a in query,
      preload: [:allowed_roles, :allowed_users, :access_settings_updated_by]
  end
end
