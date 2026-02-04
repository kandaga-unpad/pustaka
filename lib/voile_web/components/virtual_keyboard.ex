defmodule VoileWeb.Components.VirtualKeyboard do
  use Phoenix.Component

  @doc """
  Renders a virtual keyboard component.

  ## Example

      <.virtual_keyboard target="visitor_identifier" />
  """
  attr :target, :string, required: true, doc: "The ID of the input field to update"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :layout, :string, default: "qwerty", values: ~w(qwerty numeric), doc: "Keyboard layout"

  def virtual_keyboard(assigns) do
    ~H"""
    <div
      class={["virtual-keyboard bg-white rounded-lg shadow-lg p-4 border border-gray-200", @class]}
      phx-no-format
    >
      <%= if @layout == "qwerty" do %>
        <div class="keyboard-layout space-y-2">
          <!-- Number row -->
          <div class="flex gap-1 justify-center">
            <.key_button value="1" target={@target} />
            <.key_button value="2" target={@target} />
            <.key_button value="3" target={@target} />
            <.key_button value="4" target={@target} />
            <.key_button value="5" target={@target} />
            <.key_button value="6" target={@target} />
            <.key_button value="7" target={@target} />
            <.key_button value="8" target={@target} />
            <.key_button value="9" target={@target} />
            <.key_button value="0" target={@target} />
          </div>

          <!-- First letter row -->
          <div class="flex gap-1 justify-center">
            <.key_button value="Q" target={@target} />
            <.key_button value="W" target={@target} />
            <.key_button value="E" target={@target} />
            <.key_button value="R" target={@target} />
            <.key_button value="T" target={@target} />
            <.key_button value="Y" target={@target} />
            <.key_button value="U" target={@target} />
            <.key_button value="I" target={@target} />
            <.key_button value="O" target={@target} />
            <.key_button value="P" target={@target} />
          </div>

          <!-- Second letter row -->
          <div class="flex gap-1 justify-center">
            <.key_button value="A" target={@target} />
            <.key_button value="S" target={@target} />
            <.key_button value="D" target={@target} />
            <.key_button value="F" target={@target} />
            <.key_button value="G" target={@target} />
            <.key_button value="H" target={@target} />
            <.key_button value="J" target={@target} />
            <.key_button value="K" target={@target} />
            <.key_button value="L" target={@target} />
          </div>

          <!-- Third letter row -->
          <div class="flex gap-1 justify-center">
            <.key_button value="Z" target={@target} />
            <.key_button value="X" target={@target} />
            <.key_button value="C" target={@target} />
            <.key_button value="V" target={@target} />
            <.key_button value="B" target={@target} />
            <.key_button value="N" target={@target} />
            <.key_button value="M" target={@target} />
          </div>

          <!-- Bottom row with special keys -->
          <div class="flex gap-1 justify-center items-center">
            <.key_button value=" " label="Space" target={@target} wide={true} />
            <.key_button value="." target={@target} />
            <.key_button value="@" target={@target} />
            <.key_button value="-" target={@target} />
            <.key_button value="_" target={@target} />
            <button
              type="button"
              phx-click="keyboard_backspace"
              phx-value-target={@target}
              class="px-4 py-3 bg-red-500 hover:bg-red-600 text-white font-semibold rounded-lg transition-colors shadow-sm"
            >
              ⌫
            </button>
            <button
              type="button"
              phx-click="keyboard_clear"
              phx-value-target={@target}
              class="px-4 py-3 bg-gray-500 hover:bg-gray-600 text-white font-semibold rounded-lg transition-colors shadow-sm text-xs"
            >
              Clear
            </button>
          </div>
        </div>
      <% else %>
        <!-- Numeric layout -->
        <div class="keyboard-layout space-y-2">
          <div class="flex gap-2 justify-center">
            <.key_button value="1" target={@target} large={true} />
            <.key_button value="2" target={@target} large={true} />
            <.key_button value="3" target={@target} large={true} />
          </div>
          <div class="flex gap-2 justify-center">
            <.key_button value="4" target={@target} large={true} />
            <.key_button value="5" target={@target} large={true} />
            <.key_button value="6" target={@target} large={true} />
          </div>
          <div class="flex gap-2 justify-center">
            <.key_button value="7" target={@target} large={true} />
            <.key_button value="8" target={@target} large={true} />
            <.key_button value="9" target={@target} large={true} />
          </div>
          <div class="flex gap-2 justify-center">
            <.key_button value="0" target={@target} large={true} />
            <button
              type="button"
              phx-click="keyboard_backspace"
              phx-value-target={@target}
              class="px-8 py-6 bg-red-500 hover:bg-red-600 text-white font-bold text-xl rounded-lg transition-colors shadow-sm"
            >
              ⌫
            </button>
            <button
              type="button"
              phx-click="keyboard_clear"
              phx-value-target={@target}
              class="px-8 py-6 bg-gray-500 hover:bg-gray-600 text-white font-bold rounded-lg transition-colors shadow-sm"
            >
              Clear
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr :value, :string, required: true
  attr :label, :string, default: nil
  attr :target, :string, required: true
  attr :wide, :boolean, default: false
  attr :large, :boolean, default: false

  defp key_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="keyboard_input"
      phx-value-key={@value}
      phx-value-target={@target}
      class={[
        "bg-blue-500 hover:bg-blue-600 text-white font-semibold rounded-lg transition-colors shadow-sm",
        @wide && "px-12 py-3",
        @large && "px-8 py-6 text-xl",
        !@wide && !@large && "px-4 py-3"
      ]}
    >
      {if @label, do: @label, else: @value}
    </button>
    """
  end
end
