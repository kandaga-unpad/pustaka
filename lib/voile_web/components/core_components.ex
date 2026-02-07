defmodule VoileWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: VoileWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-voile-surface/90 dark:bg-voile-dark/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-voile-light dark:bg-gray-700 p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label={gettext("close")}
                >
                  <.icon name="hero-x-mark-solid" class="h-5 w-5" />
                </button>
              </div>

              <div id={"#{@id}-content"}>{render_slot(@inner_block)}</div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a reusable delete / confirm modal.

  This builds on the existing `modal/1` semantics and accepts JS commands
  for `:on_cancel` and `:on_confirm`. The inner block is used to render
  a descriptive message about what will be deleted.

  Example:

      <.delete_modal id="confirm-delete" show={@show_delete}
        title="Delete Role" confirm_label="Delete"
        on_cancel={JS.patch(~p"/items")} on_confirm={JS.push("confirm_delete", value: %{id: @item.id})}>
        Are you sure you want to delete this role? This action cannot be undone.
      </.delete_modal>

  The component uses existing project button classes so it fits the visual
  language of the app.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, default: gettext("Are you sure?")
  attr :confirm_label, :string, default: gettext("Delete")
  attr :confirm_class, :string, default: "cancel-btn"
  attr :on_cancel, JS, default: %JS{}
  attr :on_confirm, JS, default: %JS{}
  slot :inner_block, required: true

  def confirm_delete(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-voile-surface/90 dark:bg-voile-dark/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="w-full max-w-lg">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="relative rounded-xl bg-voile-light dark:bg-gray-700 p-8 shadow-lg ring-1 ring-zinc-700/10"
            >
              <div class="flex items-start gap-4">
                <div class="flex-none">
                  <.icon name="hero-exclamation-triangle-solid" class="h-8 w-8 text-voile-error" />
                </div>

                <div class="flex-1">
                  <h3 id={"#{@id}-title"} class="text-lg font-semibold">{@title}</h3>

                  <p id={"#{@id}-description"} class="mt-2 text-sm text-base-content/70">
                    {render_slot(@inner_block)}
                  </p>
                </div>
              </div>

              <div class="mt-6 flex justify-end gap-3">
                <button
                  type="button"
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  class="hover-btn"
                >
                  {gettext("Cancel")}
                </button>
                <button
                  type="button"
                  phx-click={hide(@on_confirm, "##{@id}")}
                  class={@confirm_class}
                >
                  {@confirm_label}
                </button>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>

          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}>
      <.flash kind={:info} title={gettext("Success!")} flash={@flash} />
      <.flash kind={:error} title={gettext("Error!")} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error")}
        phx-connected={hide("#client-error")}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error")}
        phx-connected={hide("#server-error")}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "primary-btn", nil => "primary-btn"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["primary-btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>{render_slot(@inner_block)}</.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>{render_slot(@inner_block)}</button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :required_value, :boolean, default: false

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}<span :if={@required_value} class="text-voile-error">*</span>
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">
          {@label}<span :if={@required_value} class="text-voile-error">*</span>
        </span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">
          {@label}<span :if={@required_value} class="text-voile-error">*</span>
        </span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">
          {@label}<span :if={@required_value} class="text-voile-error">*</span>
        </span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-voile-dark">
      {render_slot(@inner_block)}
    </label>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-voile-error">
      <.icon name="hero-exclamation-circle" class="size-5" /> {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      @actions != [] && "flex items-center justify-between gap-6",
      "pb-4 mt-10 mb-5"
    ]}>
      <div>
        <h5 class="font-semibold">{render_slot(@inner_block)}</h5>

        <p :if={@subtitle != []} class="text-sm text-base-content/70">{render_slot(@subtitle)}</p>
      </div>

      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>

          <th :if={@action != []}><span class="sr-only">{gettext("Actions")}</span></th>
        </tr>
      </thead>

      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>

          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list w-full">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold text-base">{item.title}</div>

          <div class="font-semibold italic">{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a back navigation link.

  ## Examples

      <.back navigate={~p"/posts"}>Back to posts</.back>
  """
  attr :navigate, :any, required: true
  slot :inner_block, required: true

  def back(assigns) do
    ~H"""
    <div class="mt-5">
      <.link
        navigate={@navigate}
        class="text-sm font-semibold leading-6"
      >
        <.icon name="hero-arrow-left-solid" class="h-3 w-3" /> {render_slot(@inner_block)}
      </.link>
    </div>
    """
  end

  @doc """
  Renders a universal breadcrumb navigation that works for any page depth.

  Accepts a list of breadcrumb items, where each item is a map with:
  - `:label` (required) - The text to display
  - `:path` (optional) - The navigation path. If nil, renders as plain text

  ## Examples

      <.breadcrumb items={[
        %{label: "Manage", path: ~p"/manage"},
        %{label: "Library", path: ~p"/manage/glam/library"},
        %{label: "Circulation", path: ~p"/manage/glam/library/circulation"},
        %{label: "Transactions", path: nil}
      ]} />

      <.breadcrumb items={[
        %{label: "Home", path: ~p"/"},
        %{label: "Current Page", path: nil}
      ]} />
  """
  attr :items, :list, required: true

  def breadcrumb(assigns) do
    ~H"""
    <nav class="flex mb-4" aria-label="Breadcrumb">
      <ol class="inline-flex items-center space-x-1 md:space-x-3">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <li class={if index == 0, do: "inline-flex items-center", else: ""}>
            <%= if index > 0 do %>
              <div class="flex items-center">
                <.icon name="hero-chevron-right" class="w-4 h-4 text-gray-500 dark:text-gray-400" />
                <%= if item[:path] do %>
                  <.link
                    navigate={item[:path]}
                    class="ml-1 text-sm font-medium text-gray-700 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white"
                  >
                    {item[:label]}
                  </.link>
                <% else %>
                  <span class="ml-1 text-sm font-medium text-gray-500 dark:text-gray-400">
                    {item[:label]}
                  </span>
                <% end %>
              </div>
            <% else %>
              <%= if item[:path] do %>
                <.link
                  navigate={item[:path]}
                  class="inline-flex items-center text-sm font-medium text-gray-700 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white"
                >
                  <.icon name="hero-home" class="w-4 h-4 mr-2" /> {item[:label]}
                </.link>
              <% else %>
                <div class="inline-flex items-center text-sm font-medium text-gray-700 dark:text-gray-300">
                  <.icon name="hero-home" class="w-4 h-4 mr-2" /> {item[:label]}
                </div>
              <% end %>
            <% end %>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(VoileWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(VoileWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  @doc """
  Renders a language/locale switcher dropdown.

  ## Examples

      <.locale_switcher />
      <.locale_switcher class="my-custom-class" />

  """
  attr :class, :string, default: ""
  attr :current_path, :string, default: "/"

  def locale_switcher(assigns) do
    ~H"""
    <div class={["relative inline-block", @class]} id="locale-switcher">
      <button
        type="button"
        phx-click={
          JS.toggle(
            to: "#locale-dropdown",
            in: "opacity-100 scale-100",
            out: "opacity-0 scale-95",
            display: "block"
          )
        }
        class="btn btn-ghost btn-sm gap-2"
      >
        <.icon name="hero-language" class="h-5 w-5" />
        <span class="hidden sm:inline">
          {VoileWeb.Utils.Locale.locale_flag(VoileWeb.Utils.Locale.get_locale())} {VoileWeb.Utils.Locale.locale_name(
            VoileWeb.Utils.Locale.get_locale()
          )}
        </span>
        <.icon name="hero-chevron-down" class="h-4 w-4" />
      </button>
      <div
        id="locale-dropdown"
        phx-click-away={
          JS.hide(
            to: "#locale-dropdown",
            transition: "opacity-0 scale-95"
          )
        }
        class="hidden absolute right-0 mt-2 w-52 origin-top-right rounded-md bg-base-100 shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none z-[9999] transition-all duration-100 ease-out"
      >
        <div class="py-1" role="menu" aria-orientation="vertical">
          <a
            :for={locale <- VoileWeb.Utils.Locale.all_locales()}
            href={"#{@current_path}?locale=#{locale.code}"}
            class={[
              "flex items-center gap-3 px-4 py-2 text-sm hover:bg-base-200 transition-colors",
              VoileWeb.Utils.Locale.get_locale() == locale.code &&
                "bg-base-200 font-semibold"
            ]}
            role="menuitem"
          >
            <span class="text-lg">{locale.flag}</span> <span>{locale.name}</span>
          </a>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a single GLAM card.
  """
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true
  attr :count, :integer, required: true
  attr :percentage, :float, required: true
  attr :path, :string, required: true
  attr :color, :string, required: true

  def glam_card(assigns) do
    color_classes = %{
      "purple" => "from-purple-500 to-purple-600 hover:from-purple-600 hover:to-purple-700",
      "blue" => "from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700",
      "green" => "from-green-500 to-green-600 hover:from-green-600 hover:to-green-700",
      "orange" => "from-orange-500 to-orange-600 hover:from-orange-600 hover:to-orange-700"
    }

    assigns =
      assign(
        assigns,
        :gradient_class,
        Map.get(color_classes, assigns.color, color_classes["blue"])
      )

    ~H"""
    <.link navigate={@path} class="block">
      <div class={"bg-gradient-to-r #{@gradient_class} rounded-xl p-6 text-white shadow-lg transition-all duration-200 hover:shadow-xl hover:scale-105"}>
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-3">
            <.icon name={"hero-#{@icon}"} class="w-8 h-8" />
            <h3 class="text-xl font-semibold">{@title}</h3>
          </div>
          <div class="text-right">
            <div class="text-2xl font-bold">{@count}</div>
            <div class="text-sm opacity-90">{@percentage}%</div>
          </div>
        </div>
        <p class="text-sm opacity-90">{@description}</p>
      </div>
    </.link>
    """
  end

  @doc """
  Renders members navigation cards.
  """
  attr :members_stats, :map, required: true

  def members_navigation_cards(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 mb-8">
      <.member_nav_card
        title="Manage Members"
        description="Add, edit, and manage member accounts"
        action_text="Go to Management"
        icon="users"
        path="/manage/members/management"
        color="green"
      />
      <.member_nav_card
        title="View Reports"
        description="View reports on member activity and status"
        action_text="View Reports"
        icon="chart-bar"
        path="/manage/members/reports"
        color="blue"
      />
      <.member_nav_card
        title="Role Management"
        description="Manage system roles and permissions"
        action_text="Manage Roles"
        icon="shield-check"
        path="/manage/members/management/roles"
        color="purple"
      />
    </div>
    """
  end

  @doc """
  Renders a single member navigation card.
  """
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :action_text, :string, required: true
  attr :icon, :string, required: true
  attr :path, :string, required: true
  attr :color, :string, required: true

  def member_nav_card(assigns) do
    color_classes = %{
      "green" =>
        "from-green-500 to-green-600 hover:from-green-600 hover:to-green-700 border-green-400",
      "blue" => "from-blue-500 to-blue-600 hover:from-blue-600 hover:to-blue-700 border-blue-400",
      "purple" =>
        "from-purple-500 to-purple-600 hover:from-purple-600 hover:to-purple-700 border-purple-400"
    }

    button_classes = %{
      "green" => "bg-green-600 hover:bg-green-700 text-white border-green-500",
      "blue" => "bg-blue-600 hover:bg-blue-700 text-white border-blue-500",
      "purple" => "bg-purple-600 hover:bg-purple-700 text-white border-purple-500"
    }

    assigns =
      assign(assigns,
        gradient_class: Map.get(color_classes, assigns.color, color_classes["blue"]),
        button_class: Map.get(button_classes, assigns.color, button_classes["blue"])
      )

    ~H"""
    <div class={"bg-gradient-to-br #{@gradient_class} rounded-xl p-8 text-white shadow-lg transition-all duration-300 hover:shadow-2xl hover:scale-[1.02] border-2 border-transparent hover:border-opacity-50"}>
      <div class="flex flex-col h-full">
        <div class="flex items-center gap-4 mb-6">
          <div class="flex-shrink-0">
            <div class="p-4 bg-white/20 rounded-xl backdrop-blur-sm">
              <.icon name={"hero-#{@icon}"} class="w-16 h-16" />
            </div>
          </div>
          <div class="flex-1">
            <h3 class="text-2xl font-bold mb-2">{@title}</h3>
            <p class="text-base opacity-95 leading-relaxed">{@description}</p>
          </div>
        </div>

        <div class="mt-auto">
          <.link
            navigate={@path}
            class={"inline-flex items-center justify-center gap-3 px-6 py-4 rounded-lg font-semibold text-lg transition-all duration-200 hover:scale-105 shadow-lg #{@button_class}"}
          >
            <.icon name="hero-arrow-right" class="w-6 h-6" />
            {@action_text}
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a recent member item.
  """
  attr :member, :map, required: true

  def recent_member_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-600 rounded-lg">
      <div class="flex items-center gap-3">
        <div class="flex-shrink-0 h-10 w-10">
          <div class="h-10 w-10 rounded-full bg-voile-light flex items-center justify-center">
            <span class="text-sm font-medium text-gray-700">
              {String.first(@member.fullname || "?")}
            </span>
          </div>
        </div>
        <div>
          <p class="text-sm font-medium text-gray-900 dark:text-white">{@member.fullname}</p>
          <p class="text-xs text-gray-500 dark:text-gray-400">
            {@member.username} • {format_date(@member.inserted_at)}
          </p>
        </div>
      </div>
      <div class="text-right">
        <span class={"inline-flex px-2 py-1 text-xs font-semibold rounded-full #{if @member.manually_suspended, do: "bg-red-100 text-red-800", else: "bg-green-100 text-green-800"}"}>
          {if @member.manually_suspended, do: "Suspended", else: "Active"}
        </span>
      </div>
    </div>
    """
  end

  # Helper function
  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
