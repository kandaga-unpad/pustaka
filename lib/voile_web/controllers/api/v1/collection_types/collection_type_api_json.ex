defmodule VoileWeb.API.V1.CollectionTypes.CollectionTypeApiJSON do
  alias Voile.Schema.Metadata.ResourceClass

  @doc """
  Render a list of collection types (GLAM type summaries or resource classes).
  """
  def index(%{collection_types: collection_types, pagination: pagination}) do
    %{
      data: for(item <- collection_types, do: collection_type_data(item)),
      pagination: %{
        page_number: pagination.page_number,
        page_size: pagination.page_size,
        total_pages: pagination.total_pages
      }
    }
  end

  # Handle GLAM type summary (map with name and total_count)
  defp collection_type_data(%{name: name, total_count: total_count}) do
    %{
      name: name,
      total_count: total_count
    }
  end

  # Handle ResourceClass struct
  defp collection_type_data(%ResourceClass{} = resource_class) do
    %{
      id: resource_class.id,
      label: resource_class.label,
      local_name: resource_class.local_name,
      information: resource_class.information,
      glam_type: resource_class.glam_type,
      vocabulary: vocabulary_data(resource_class.vocabulary),
      inserted_at: resource_class.inserted_at,
      updated_at: resource_class.updated_at
    }
  end

  # Handle vocabulary data
  defp vocabulary_data(nil), do: nil

  defp vocabulary_data(vocabulary) do
    %{
      id: vocabulary.id,
      name: vocabulary.name,
      description: vocabulary.description
    }
  end
end
