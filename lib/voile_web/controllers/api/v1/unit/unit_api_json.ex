defmodule VoileWeb.API.V1.Unit.UnitApiJson do
  alias Voile.Schema.System.Node

  @doc """
  Render a list of units.
  """
  def index(%{units: units}) do
    %{
      data: for(unit <- units, do: data(unit))
    }
  end

  defp data(%Node{} = unit) do
    %{
      id: unit.id,
      name: unit.name,
      image: unit.image,
      abbr: unit.abbr,
      description: unit.description,
      inserted_at: unit.inserted_at,
      updated_at: unit.updated_at
    }
  end
end
