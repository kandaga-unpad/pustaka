defmodule VoileWeb.Components.LabelComponentsTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  test "renders full barcode string in label preview" do
    item = %{
      barcode: "1775453915933176365fe1994001",
      collection: %{title: "Test Collection", collection_fields: []},
      item_location: %{location_name: "Main Shelf"},
      node: %{name: "Main Node"}
    }

    html =
      render_component(&VoileWeb.Components.LabelComponents.label_preview/1, %{
        item: item,
        include_barcode: true,
        include_location: true,
        include_call_number: false,
        include_border: false,
        app_logo_url: nil
      })

    assert html =~ "1775453915933176365fe1994001"
  end
end
