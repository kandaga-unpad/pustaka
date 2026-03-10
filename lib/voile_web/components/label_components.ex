defmodule VoileWeb.Components.LabelComponents do
  @moduledoc """
  Label printing components for library items
  """
  use Phoenix.Component

  attr :item, :map, required: true
  attr :size, :string, default: "medium"
  attr :font_size, :string, default: "base"
  attr :include_barcode, :boolean, default: true
  attr :include_location, :boolean, default: true
  attr :include_call_number, :boolean, default: true
  attr :include_border, :boolean, default: true
  attr :app_logo_url, :string, default: nil

  def label_preview(assigns) do
    ~H"""
    <div
      class={[
        "print-label rounded overflow-hidden bg-white flex flex-col",
        if(@include_border, do: "border-2 border-dashed border-gray-300", else: "")
      ]}
      style="width: 7.5cm; height: 3.5cm; box-sizing: border-box; padding: 2mm 3mm;"
    >
      <%!-- Node Name + Location with optional logo --%>
      <%= if @app_logo_url || @include_location do %>
        <div style="display: flex; justify-content: center;">
          <div style="display: flex; align-items: center; gap: 3px;">
            <%= if @app_logo_url do %>
              <img
                src={@app_logo_url}
                style="width: 18px; height: 18px; object-fit: contain; flex-shrink: 0;"
              />
            <% end %>
            <%= if @include_location do %>
              <div style="overflow: hidden;">
                <div style="font-size: 8px; color: #1f2937; font-weight: 700; line-height: 1.3; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                  {get_node_name(@item)}
                </div>
                <div style="font-size: 6px; color: #9ca3af; line-height: 1.3; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                  {get_location(@item)}
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      <%!-- Title --%>
      <div style="font-size: 6px; color: #4b5563; line-height: 1.3; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; margin-top: 1px; text-align: center;">
        {@item.collection.title}
      </div>
      <%!-- Barcode --%>
      <%= if @include_barcode do %>
        <div style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 50px; margin-top: 2px;">
          <div style="width: 100%; line-height: 0; overflow: hidden; text-align: center;">
            {Phoenix.HTML.raw(generate_barcode_small(@item.barcode || "000000"))}
          </div>
          <div style="font-size: 7px; font-family: ui-monospace, monospace; color: #6b7280; line-height: 1.3; margin-top: 2px; letter-spacing: 0.05em; text-align: center;">
            {@item.barcode || "000000"}
          </div>
        </div>
      <% end %>
      <%!-- Call Number --%>
      <%= if @include_call_number do %>
        <div style="font-size: 9px; font-family: ui-monospace, monospace; font-weight: 700; color: #111827; line-height: 1.2; border-top: 1px solid #d1d5db; padding-top: 2px; margin-top: 1px; flex-shrink: 0; text-align: center;">
          {get_call_number(@item)}
        </div>
      <% end %>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :size, :string, default: "medium"
  attr :font_size, :string, default: "base"
  attr :include_barcode, :boolean, default: true
  attr :include_location, :boolean, default: true
  attr :include_call_number, :boolean, default: true
  attr :include_border, :boolean, default: true
  attr :app_logo_url, :string, default: nil

  def label_print(assigns) do
    ~H"""
    <div
      class="print-label overflow-hidden bg-white flex flex-col"
      style={"width: 7.5cm; height: 3.5cm; box-sizing: border-box; padding: 2mm 3mm; background-color: white !important;#{if @include_border, do: " border: 1px solid #9ca3af;", else: ""}"}
    >
      <%!-- Node Name + Location with optional logo --%>
      <%= if @app_logo_url || @include_location do %>
        <div style="display: flex; justify-content: center;">
          <div style="display: flex; align-items: center; gap: 3px;">
            <%= if @app_logo_url do %>
              <img
                src={@app_logo_url}
                style="width: 18px; height: 18px; object-fit: contain; flex-shrink: 0;"
              />
            <% end %>
            <%= if @include_location do %>
              <div style="overflow: hidden;">
                <div style="font-size: 8px; color: #1f2937 !important; font-weight: 700; line-height: 1.3; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                  {get_node_name(@item)}
                </div>
                <div style="font-size: 6px; color: #9ca3af !important; line-height: 1.3; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                  {get_location(@item)}
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      <%!-- Title --%>
      <div style="font-size: 6px; color: #4b5563 !important; line-height: 1.3; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; margin-top: 1px; text-align: center;">
        {@item.collection.title}
      </div>
      <%!-- Barcode --%>
      <%= if @include_barcode do %>
        <div style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 50px; margin-top: 2px;">
          <div style="width: 100%; line-height: 0; overflow: hidden; text-align: center;">
            {Phoenix.HTML.raw(generate_barcode_small(@item.barcode || "000000"))}
          </div>
          <div style="font-size: 7px; font-family: ui-monospace, monospace; color: #6b7280 !important; line-height: 1.3; margin-top: 2px; letter-spacing: 0.05em; text-align: center;">
            {@item.barcode || "000000"}
          </div>
        </div>
      <% end %>
      <%!-- Call Number --%>
      <%= if @include_call_number do %>
        <div style="font-size: 9px; font-family: ui-monospace, monospace; font-weight: 700; color: #111827 !important; line-height: 1.2; border-top: 1px solid #d1d5db !important; padding-top: 2px; margin-top: 1px; flex-shrink: 0; text-align: center;">
          {get_call_number(@item)}
        </div>
      <% end %>
    </div>
    """
  end

  defp get_call_number(item) do
    # Get call number from collection_fields only
    call_number_field =
      Enum.find(item.collection.collection_fields || [], fn field ->
        field.name == "callNumber" || field.name == "CallNumber" || field.name == "noPanggil" ||
          field.name == "no_panggil"
      end)

    if call_number_field && call_number_field.value != "" do
      call_number_field.value
    else
      "-"
    end
  end

  defp get_node_name(item) do
    cond do
      item.node && item.node.name -> item.node.name
      true -> "N/A"
    end
  end

  defp get_location(item) do
    cond do
      item.item_location && item.item_location.location_name -> item.item_location.location_name
      item.location && item.location != "" -> item.location
      true -> "-"
    end
  end

  # Generate compact Code 128 barcode as SVG for small labels (7.5cm × 3.5cm)
  defp generate_barcode_small(text) when is_binary(text) do
    clean_text = String.trim(text)

    barcode_text =
      if String.length(clean_text) > 20 do
        parts = String.split(clean_text, "-")

        cond do
          length(parts) >= 6 ->
            uuid_part = Enum.at(parts, -3) || ""
            sequence = List.last(parts) || ""
            uuid_part <> sequence

          true ->
            String.slice(clean_text, -15, 15)
        end
      else
        clean_text
      end

    try do
      case barcode_text
           |> Barlix.Code128.encode!()
           |> Barlix.SVG.print(xdim: 2, height: 55, margin: 4) do
        {:ok, svg} ->
          svg
          |> String.replace(
            "<svg ",
            "<svg style=\"width: 100%; height: 60px; display: block; max-height: 60px;\" "
          )

        _ ->
          ""
      end
    rescue
      _ -> ""
    end
  end

  defp generate_barcode_small(_), do: ""
end
