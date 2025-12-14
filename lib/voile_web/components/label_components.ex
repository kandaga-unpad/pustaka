defmodule VoileWeb.Components.LabelComponents do
  @moduledoc """
  Label printing components for library items
  """
  use Phoenix.Component
  import VoileWeb.CoreComponents
  alias Voile.Schema.System

  attr :item, :map, required: true
  attr :size, :string, default: "medium"
  attr :font_size, :string, default: "base"
  attr :include_barcode, :boolean, default: true
  attr :include_location, :boolean, default: true
  attr :include_call_number, :boolean, default: true

  def label_preview(assigns) do
    assigns = assign(assigns, :app_name, System.get_setting_value("app_name", "Library"))
    assigns = assign(assigns, :app_logo, System.get_setting_value("app_logo_url"))

    ~H"""
    <div class={[
      "print-label border-2 border-dashed border-gray-300 rounded overflow-hidden bg-white flex flex-row",
      size_class(@size)
    ]}>
      <%!-- Left Side: Barcode --%>
      <%= if @include_barcode do %>
        <div class="flex-1 border-r border-gray-300 p-2 flex flex-col items-center justify-center">
          <div class="w-full flex justify-center mb-2">
            {Phoenix.HTML.raw(generate_barcode(@item.barcode || "000000"))}
          </div>
          
          <div class="text-center text-[0.5rem] font-mono text-gray-700 break-all px-1">
            {@item.barcode || "000000"}
          </div>
        </div>
      <% end %>
       <%!-- Right Side: Metadata --%>
      <div class={["flex-1 flex flex-col", (@include_barcode && "pl-2") || ""]}>
        <%!-- App Branding --%>
        <div class="bg-gray-50 border-b border-gray-200 px-2 py-1 flex items-center justify-center gap-1">
          <%= if @app_logo do %>
            <img src={@app_logo} alt={@app_name} class="h-6 w-auto" />
          <% end %>
           <span class="text-sm font-bold text-gray-700">{@app_name}</span>
        </div>
         <%!-- Color Bars (Flag on top) --%>
        <div class="flex flex-col h-3 flex-shrink-0">
          <div class={["flex-1", book_type_color(@item)]} title={get_book_type(@item)}></div>
          
          <div class={["flex-1", ddc_color(@item)]} title={"DDC: #{get_ddc_class(@item)}"}></div>
        </div>
        
        <div class={["space-y-0.5 p-2 flex-1 text-center", font_class(@font_size)]}>
          <%!-- Collection Title (line-clamped for long titles) --%>
          <div class="font-bold text-gray-900 line-clamp-2 leading-tight text-xs">
            {@item.collection.title}
          </div>
           <%!-- Author --%>
          <%= if get_author(@item) != "N/A" do %>
            <div class="text-gray-600 text-[0.65rem] italic line-clamp-1">{get_author(@item)}</div>
          <% end %>
           <%!-- Call Number --%>
          <%= if @include_call_number do %>
            <div class="font-mono text-gray-800 font-semibold text-xs">{get_call_number(@item)}</div>
          <% end %>
           <%!-- Node Name --%>
          <%= if @include_location do %>
            <div class="text-gray-600 text-[0.5rem] mt-1">
              <.icon name="hero-map-pin" class="w-2.5 h-2.5 inline" /> {get_node_name(@item)}
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :size, :string, default: "medium"
  attr :font_size, :string, default: "base"
  attr :include_barcode, :boolean, default: true
  attr :include_location, :boolean, default: true
  attr :include_call_number, :boolean, default: true

  def label_print(assigns) do
    assigns = assign(assigns, :app_name, System.get_setting_value("app_name", "Library"))
    assigns = assign(assigns, :app_logo, System.get_setting_value("app_logo_url"))

    ~H"""
    <div class={[
      "print-label border border-gray-400 overflow-hidden bg-white flex flex-row",
      size_class(@size)
    ]}>
      <%!-- Left Side: Barcode --%>
      <%= if @include_barcode do %>
        <div
          class="flex-1 border-r border-gray-400 p-2 flex flex-col items-center justify-center"
          style="border-right: 1px solid #9ca3af !important;"
        >
          <div
            class="w-full flex justify-center mb-2"
            style="width: 100% !important; display: flex !important; justify-content: center !important; margin-bottom: 0.5rem !important;"
          >
            {Phoenix.HTML.raw(generate_barcode(@item.barcode || "000000"))}
          </div>
          
          <div
            class="text-center text-[0.5rem] font-mono text-gray-700 break-all px-1"
            style="text-align: center !important; font-size: 0.5rem !important; font-family: ui-monospace, monospace !important; color: #374151 !important; word-break: break-all !important; padding-left: 0.25rem !important; padding-right: 0.25rem !important;"
          >
            {@item.barcode || "000000"}
          </div>
        </div>
      <% end %>
       <%!-- Right Side: Metadata --%>
      <div class={["flex-1 flex flex-col", (@include_barcode && "pl-2") || ""]}>
        <%!-- App Branding --%>
        <div
          class="bg-gray-50 border-b border-gray-300 px-2 py-1 flex items-center justify-center gap-1"
          style="background-color: #f9fafb !important; border-bottom: 1px solid #d1d5db !important;"
        >
          <%= if @app_logo do %>
            <img src={@app_logo} alt={@app_name} class="h-6 w-auto" />
          <% end %>
          
          <span
            class="text-sm font-bold text-gray-700"
            style="color: #374151 !important; font-size: 0.875rem !important; font-weight: 700 !important;"
          >
            {@app_name}
          </span>
        </div>
         <%!-- Color Bars (Flag on top) with inline styles for print --%>
        <div class="flex flex-col h-6 flex-shrink-0">
          <div class={["flex-1", book_type_color(@item)]} style={book_type_color_style(@item)}></div>
          
          <div class={["flex-1", ddc_color(@item)]} style={ddc_color_style(@item)}></div>
        </div>
        
        <div class={["space-y-0.5 p-2 flex-1 text-center", font_class(@font_size)]}>
          <%!-- Collection Title (line-clamped for long titles) --%>
          <div class="font-bold text-gray-900 leading-tight text-xs line-clamp-2">
            {@item.collection.title}
          </div>
           <%!-- Author --%>
          <%= if get_author(@item) != "N/A" do %>
            <div class="text-gray-700 text-[0.65rem] italic line-clamp-1">{get_author(@item)}</div>
          <% end %>
           <%!-- Call Number --%>
          <%= if @include_call_number do %>
            <div class="font-mono text-gray-800 font-bold text-xs">{get_call_number(@item)}</div>
          <% end %>
           <%!-- Node Name --%>
          <%= if @include_location do %>
            <div class="text-gray-600 text-[0.5rem] mt-1">📍 {get_node_name(@item)}</div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # A4 paper width ~21cm, 2 labels per row with margins
  # All labels use 10.5cm width to prevent text cropping
  # Small: 10.5cm × 3cm
  # Medium: 10.5cm × 4cm
  # Large: 10.5cm × 5cm
  defp size_class("small"), do: "w-[24.8rem] h-[7rem] text-xs"
  defp size_class("medium"), do: "w-[24.8rem] h-[9.5rem] text-sm"
  defp size_class("large"), do: "w-[24.8rem] h-[11.8rem] text-base"
  defp size_class(_), do: "w-[24.8rem] h-[9.5rem] text-sm"

  defp font_class("xs"), do: "text-xs"
  defp font_class("sm"), do: "text-sm"
  defp font_class("base"), do: "text-base"
  defp font_class("lg"), do: "text-lg"
  defp font_class(_), do: "text-base"

  # Book Type Color (Koleksi Tandon = Green, Koleksi Sirkulasi = Orange)
  defp book_type_color(item) do
    type = get_book_type(item) |> String.downcase()

    cond do
      String.contains?(type, "tandon") -> "bg-green-500"
      String.contains?(type, "sirkulasi") -> "bg-orange-500"
      # Bright red for unknown/uncategorized
      true -> "bg-red-600"
    end
  end

  # Book Type Color Inline Style (for print compatibility)
  defp book_type_color_style(item) do
    type = get_book_type(item) |> String.downcase()

    cond do
      # Green
      String.contains?(type, "tandon") -> "background-color: #22c55e !important;"
      # Orange
      String.contains?(type, "sirkulasi") -> "background-color: #f97316 !important;"
      # Bright red for unknown
      true -> "background-color: #dc2626 !important;"
    end
  end

  # DDC Classification Color based on hundreds digit (000-999)
  defp ddc_color(item) do
    call_number = get_call_number(item)

    # Extract first 3 digits from call number (e.g., "371.96 Rob i" -> "371")
    case Regex.run(~r/^(\d{1,3})/, call_number) do
      [_, digits] ->
        ddc_class = String.to_integer(digits)

        cond do
          # 000-099: Computer Science, Information & General Works - Blue
          ddc_class >= 0 && ddc_class < 100 -> "bg-blue-500"
          # 100-199: Philosophy & Psychology - Purple
          ddc_class >= 100 && ddc_class < 200 -> "bg-purple-500"
          # 200-299: Religion - Yellow/Gold
          ddc_class >= 200 && ddc_class < 300 -> "bg-yellow-500"
          # 300-399: Social Sciences - Green
          ddc_class >= 300 && ddc_class < 400 -> "bg-green-500"
          # 400-499: Language - Cyan
          ddc_class >= 400 && ddc_class < 500 -> "bg-cyan-500"
          # 500-599: Science - Teal
          ddc_class >= 500 && ddc_class < 600 -> "bg-teal-500"
          # 600-699: Technology - Orange
          ddc_class >= 600 && ddc_class < 700 -> "bg-orange-500"
          # 700-799: Arts & Recreation - Pink
          ddc_class >= 700 && ddc_class < 800 -> "bg-pink-500"
          # 800-899: Literature - Indigo
          ddc_class >= 800 && ddc_class < 900 -> "bg-indigo-500"
          # 900-999: History & Geography - Amber/Brown
          ddc_class >= 900 && ddc_class < 1000 -> "bg-amber-600"
          # Bright red for unknown
          true -> "bg-red-600"
        end

      _ ->
        # Bright red for unknown
        "bg-red-600"
    end
  end

  # DDC Classification Color Inline Style (for print compatibility)
  defp ddc_color_style(item) do
    call_number = get_call_number(item)

    case Regex.run(~r/^(\d{1,3})/, call_number) do
      [_, digits] ->
        ddc_class = String.to_integer(digits)

        cond do
          # 000-099: Computer Science - Blue
          ddc_class >= 0 && ddc_class < 100 -> "background-color: #3b82f6 !important;"
          # 100-199: Philosophy - Purple
          ddc_class >= 100 && ddc_class < 200 -> "background-color: #a855f7 !important;"
          # 200-299: Religion - Yellow/Gold
          ddc_class >= 200 && ddc_class < 300 -> "background-color: #eab308 !important;"
          # 300-399: Social Sciences - Green
          ddc_class >= 300 && ddc_class < 400 -> "background-color: #22c55e !important;"
          # 400-499: Language - Cyan
          ddc_class >= 400 && ddc_class < 500 -> "background-color: #06b6d4 !important;"
          # 500-599: Science - Teal
          ddc_class >= 500 && ddc_class < 600 -> "background-color: #14b8a6 !important;"
          # 600-699: Technology - Orange
          ddc_class >= 600 && ddc_class < 700 -> "background-color: #f97316 !important;"
          # 700-799: Arts - Pink
          ddc_class >= 700 && ddc_class < 800 -> "background-color: #ec4899 !important;"
          # 800-899: Literature - Indigo
          ddc_class >= 800 && ddc_class < 900 -> "background-color: #6366f1 !important;"
          # 900-999: History - Amber/Brown
          ddc_class >= 900 && ddc_class < 1000 -> "background-color: #d97706 !important;"
          # Bright red for unknown
          true -> "background-color: #dc2626 !important;"
        end

      _ ->
        # Bright red for unknown
        "background-color: #dc2626 !important;"
    end
  end

  defp get_book_type(item) do
    # Try to find bookType or collectionType field
    type_field =
      Enum.find(item.collection.collection_fields || [], fn field ->
        field.name in ["bookType", "collectionType", "type", "tipe"]
      end)

    if type_field && type_field.value != "", do: type_field.value, else: "N/A"
  end

  defp get_ddc_class(item) do
    call_number = get_call_number(item)

    case Regex.run(~r/^(\d{1,3})/, call_number) do
      [_, digits] -> digits
      _ -> "N/A"
    end
  end

  defp get_author(item) do
    # Get author from mst_creator relationship
    cond do
      item.collection.mst_creator && item.collection.mst_creator.creator_name ->
        item.collection.mst_creator.creator_name

      true ->
        "N/A"
    end
  end

  defp get_call_number(item) do
    # Get call number from collection_fields only
    call_number_field =
      Enum.find(item.collection.collection_fields || [], fn field ->
        field.name == "callNumber"
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

  # Generate Code 128 barcode as SVG using Barlix library
  defp generate_barcode(text) when is_binary(text) do
    # Clean the text
    clean_text = String.trim(text)

    # For very long codes (like UUIDs), extract a unique but scannable portion
    # Format: kandaga-book-9c195395-d002-4c2a-8bfb-c47e6d008b3a-1761276668-001
    # Strategy: Use full last UUID segment + sequence number for maximum uniqueness
    barcode_text =
      if String.length(clean_text) > 20 do
        parts = String.split(clean_text, "-")

        cond do
          # If it has UUID format (multiple segments), use last UUID segment + sequence
          length(parts) >= 6 ->
            # c47e6d008b3a (full segment)
            uuid_part = Enum.at(parts, -3) || ""
            # 001
            sequence = List.last(parts) || ""
            # Use full UUID segment + sequence = 15 chars total (very readable)
            uuid_part <> sequence

          # If format is different, take last 15 characters
          true ->
            String.slice(clean_text, -15, 15)
        end
      else
        clean_text
      end

    # Generate proper Code 128 barcode using Barlix with optimized settings
    try do
      case barcode_text
           |> Barlix.Code128.encode!()
           |> Barlix.SVG.print(xdim: 3, height: 60, margin: 10) do
        {:ok, svg} ->
          # Add inline styles to ensure proper display and printing
          svg
          |> String.replace(
            "<svg ",
            "<svg style=\"max-width: 100%; height: 70px; display: block;\" "
          )

        _ ->
          ""
      end
    rescue
      _ ->
        # Fallback to empty if encoding fails
        ""
    end
  end

  defp generate_barcode(_), do: ""
end
