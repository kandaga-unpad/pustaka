defmodule VoileWeb.Components.VirtualKeyboard do
  use Phoenix.Component
  import VoileWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a virtual keyboard component with tabs.

  ## Example

      <.virtual_keyboard target="visitor_identifier" />
  """
  attr :target, :string, required: true, doc: "The ID of the input field to update"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :shift_active, :boolean, default: false, doc: "Whether shift/caps is active for uppercase"

  def virtual_keyboard(assigns) do
    ~H"""
    <div
      class={[
        "virtual-keyboard bg-white dark:bg-gray-800 rounded-lg shadow-lg border border-gray-200 dark:border-gray-700",
        @class
      ]}
      id="virtual-keyboard-container"
      phx-hook="VirtualKeyboardTab"
    >
      <!-- Tab Navigation -->
      <div class="flex border-b border-gray-200 dark:border-gray-700">
        <button
          type="button"
          class="flex-1 py-3 px-4 text-sm font-medium transition-colors keyboard-tab"
          data-tab="number"
        >
          <.icon name="hero-calculator" class="w-5 h-5 inline-block mr-1" /> Number
        </button>
        <button
          type="button"
          class="flex-1 py-3 px-4 text-sm font-medium transition-colors keyboard-tab"
          data-tab="keyboard"
        >
          <.icon name="hero-keyboard" class="w-5 h-5 inline-block mr-1" /> Keyboard
        </button>
        <button
          type="button"
          class="flex-1 py-3 px-4 text-sm font-medium transition-colors keyboard-tab"
          data-tab="info"
        >
          <.icon name="hero-information-circle" class="w-5 h-5 inline-block mr-1" /> Info
        </button>
      </div>
      
    <!-- Tab Content -->
      <div class="p-4">
        <!-- Number Mode Tab -->
        <div class="keyboard-content" data-content="number">
          <div class="space-y-2">
            <!-- Row 1 -->
            <div class="grid grid-cols-3 gap-2">
              <.key_button value="1" target={@target} large={true} />
              <.key_button value="2" target={@target} large={true} />
              <.key_button value="3" target={@target} large={true} />
            </div>
            <!-- Row 2 -->
            <div class="grid grid-cols-3 gap-2">
              <.key_button value="4" target={@target} large={true} />
              <.key_button value="5" target={@target} large={true} />
              <.key_button value="6" target={@target} large={true} />
            </div>
            <!-- Row 3 -->
            <div class="grid grid-cols-3 gap-2">
              <.key_button value="7" target={@target} large={true} />
              <.key_button value="8" target={@target} large={true} />
              <.key_button value="9" target={@target} large={true} />
            </div>
            <!-- Row 4 -->
            <div class="grid grid-cols-3 gap-2">
              <button
                type="button"
                phx-click="keyboard_clear"
                phx-value-target={@target}
                class="px-6 py-4 bg-yellow-500 hover:bg-yellow-600 dark:bg-yellow-600 dark:hover:bg-yellow-700 text-white font-bold text-lg rounded-lg transition-colors shadow-sm"
              >
                Clear
              </button>
              <.key_button value="0" target={@target} large={true} />
              <button
                type="button"
                phx-click="keyboard_backspace"
                phx-value-target={@target}
                class="px-6 py-4 bg-red-500 hover:bg-red-600 dark:bg-red-600 dark:hover:bg-red-700 text-white font-bold text-xl rounded-lg transition-colors shadow-sm"
              >
                ⌫
              </button>
            </div>
          </div>
        </div>
        
    <!-- Keyboard Mode Tab -->
        <div class="keyboard-content hidden" data-content="keyboard">
          <div class="space-y-2">
            <!-- First letter row (QWERTY) -->
            <div class="grid grid-cols-10 gap-2">
              <.key_button value={if @shift_active, do: "Q", else: "q"} target={@target} />
              <.key_button value={if @shift_active, do: "W", else: "w"} target={@target} />
              <.key_button value={if @shift_active, do: "E", else: "e"} target={@target} />
              <.key_button value={if @shift_active, do: "R", else: "r"} target={@target} />
              <.key_button value={if @shift_active, do: "T", else: "t"} target={@target} />
              <.key_button value={if @shift_active, do: "Y", else: "y"} target={@target} />
              <.key_button value={if @shift_active, do: "U", else: "u"} target={@target} />
              <.key_button value={if @shift_active, do: "I", else: "i"} target={@target} />
              <.key_button value={if @shift_active, do: "O", else: "o"} target={@target} />
              <.key_button value={if @shift_active, do: "P", else: "p"} target={@target} />
            </div>
            
    <!-- Second letter row (ASDFGH) with apostrophe -->
            <div class="grid grid-cols-10 gap-2">
              <.key_button value={if @shift_active, do: "A", else: "a"} target={@target} />
              <.key_button value={if @shift_active, do: "S", else: "s"} target={@target} />
              <.key_button value={if @shift_active, do: "D", else: "d"} target={@target} />
              <.key_button value={if @shift_active, do: "F", else: "f"} target={@target} />
              <.key_button value={if @shift_active, do: "G", else: "g"} target={@target} />
              <.key_button value={if @shift_active, do: "H", else: "h"} target={@target} />
              <.key_button value={if @shift_active, do: "J", else: "j"} target={@target} />
              <.key_button value={if @shift_active, do: "K", else: "k"} target={@target} />
              <.key_button value={if @shift_active, do: "L", else: "l"} target={@target} />
              <.key_button value="'" target={@target} />
            </div>
            
    <!-- Third letter row (ZXCVBN) with comma, dot, hyphen -->
            <div class="grid grid-cols-10 gap-2">
              <.key_button value={if @shift_active, do: "Z", else: "z"} target={@target} />
              <.key_button value={if @shift_active, do: "X", else: "x"} target={@target} />
              <.key_button value={if @shift_active, do: "C", else: "c"} target={@target} />
              <.key_button value={if @shift_active, do: "V", else: "v"} target={@target} />
              <.key_button value={if @shift_active, do: "B", else: "b"} target={@target} />
              <.key_button value={if @shift_active, do: "N", else: "n"} target={@target} />
              <.key_button value={if @shift_active, do: "M", else: "m"} target={@target} />
              <.key_button value="," target={@target} />
              <.key_button value="." target={@target} />
              <.key_button value="-" target={@target} />
            </div>
            
    <!-- Control buttons row: Shift | Clear | Space | Delete (full width) -->
            <div class="grid grid-cols-4 gap-2">
              <button
                type="button"
                phx-click="keyboard_toggle_shift"
                class={[
                  "py-3 font-semibold rounded-lg transition-colors shadow-sm",
                  @shift_active &&
                    "bg-green-500 hover:bg-green-600 dark:bg-green-600 dark:hover:bg-green-700 text-white",
                  !@shift_active &&
                    "bg-gray-400 hover:bg-gray-500 dark:bg-gray-600 dark:hover:bg-gray-700 text-white"
                ]}
              >
                ⇧ Shift
              </button>
              <button
                type="button"
                phx-click="keyboard_clear"
                phx-value-target={@target}
                class="py-3 bg-yellow-500 hover:bg-yellow-600 dark:bg-yellow-600 dark:hover:bg-yellow-700 text-white font-semibold rounded-lg transition-colors shadow-sm"
              >
                Clear
              </button>
              <button
                type="button"
                phx-click="keyboard_input"
                phx-value-key=" "
                phx-value-target={@target}
                class="py-3 bg-blue-500 hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors shadow-sm"
              >
                Space
              </button>
              <button
                type="button"
                phx-click="keyboard_backspace"
                phx-value-target={@target}
                class="py-3 bg-red-500 hover:bg-red-600 dark:bg-red-600 dark:hover:bg-red-700 text-white font-semibold text-lg rounded-lg transition-colors shadow-sm"
              >
                ⌫ Delete
              </button>
            </div>
          </div>
        </div>
        
    <!-- Information Mode Tab -->
        <div class="keyboard-content hidden" data-content="info">
          <div class="space-y-4 text-gray-700 dark:text-gray-300">
            <div class="text-center">
              <h3 class="text-xl font-bold text-blue-600 dark:text-blue-400 mb-2">
                Voile - Visitor Management System
              </h3>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                Version 0.1.0
              </p>
            </div>

            <div class="border-t border-gray-200 dark:border-gray-700 pt-4">
              <h4 class="font-semibold mb-2 text-gray-800 dark:text-gray-200">
                About This System
              </h4>
              <p class="text-sm leading-relaxed">
                This visitor management system helps track and manage visitor check-ins
                and feedback efficiently. Built with modern web technologies to provide
                a seamless experience.
              </p>
            </div>

            <div class="border-t border-gray-200 dark:border-gray-700 pt-4">
              <h4 class="font-semibold mb-2 text-gray-800 dark:text-gray-200">
                How to Use
              </h4>
              <ul class="text-sm space-y-2 list-disc list-inside">
                <li>Select your location from the available options</li>
                <li>Enter your ID or student number using the virtual keyboard</li>
                <li>Choose your visitor type from the dropdown</li>
                <li>Click "Check In Now" to complete registration</li>
                <li>Share your feedback using the survey form (optional)</li>
              </ul>
            </div>

            <div class="border-t border-gray-200 dark:border-gray-700 pt-4">
              <h4 class="font-semibold mb-2 text-gray-800 dark:text-gray-200">
                Keyboard Features
              </h4>
              <ul class="text-sm space-y-2 list-disc list-inside">
                <li><strong>Number Mode:</strong> Quick numeric input for IDs</li>
                <li><strong>Keyboard Mode:</strong> Full QWERTY keyboard with special characters</li>
                <li><strong>Info Mode:</strong> System information and usage guide</li>
              </ul>
            </div>

            <div class="border-t border-gray-200 dark:border-gray-700 pt-4 text-center">
              <p class="text-xs text-gray-500 dark:text-gray-500">
                Powered by Phoenix LiveView & Elixir
              </p>
              <p class="text-xs text-gray-500 dark:text-gray-500 mt-1">
                © 2024 Voile. All rights reserved.
              </p>
            </div>
          </div>
        </div>
      </div>
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
        "bg-blue-500 hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors shadow-sm",
        @wide && "px-8 py-3 min-w-[120px]",
        @large && "px-6 py-4 text-lg",
        !@wide && !@large && "py-3"
      ]}
    >
      {if @label, do: @label, else: @value}
    </button>
    """
  end
end
