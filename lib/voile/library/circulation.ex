defmodule Voile.Library.Circulation do
  alias Voile.Schema.Catalog

  def check_availability(item_id) do
    item = Catalog.get_item!(item_id)

    {:ok, item}
  end
end
