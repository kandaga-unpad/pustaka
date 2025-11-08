#!/usr/bin/env elixir

# RBAC Implementation Helper Script
# This script helps quickly implement RBAC checks across multiple similar modules

defmodule RBACImplementationHelper do
  @moduledoc """
  Helper script to generate RBAC implementation code for master data modules.
  """

  @master_modules [
    {"publisher", "Publisher"},
    {"member_type", "MemberType"},
    {"frequency", "Frequency"},
    {"locations", "Location"},
    {"places", "Place"},
    {"topic", "Topic"}
  ]

  def generate_mount_check(permission \\ "metadata.manage") do
    """
    @impl true
    def mount(_params, _session, socket) do
      # Check permission for managing metadata/master data
      authorize!(socket, "#{permission}")

      # ... rest of mount logic
    """
  end

  def generate_apply_action_checks() do
    """
    defp apply_action(socket, :new, _params) do
      authorize!(socket, "metadata.manage")
      # ... rest of new action
    end

    defp apply_action(socket, :edit, %{"id" => id}) do
      authorize!(socket, "metadata.manage")
      # ... rest of edit action
    end
    """
  end

  def generate_delete_check() do
    """
    def handle_event("delete", %{"id" => id}, socket) do
      authorize!(socket, "metadata.manage")
      # ... rest of delete logic
    end
    """
  end

  def generate_template_button_check(resource_path) do
    """
    <%%= if can?(@current_scope.user, "metadata.manage") do %>
      <.link patch={~p"/manage/master/#{resource_path}/new"}>
        <.button>New <%= String.capitalize(resource_path) %></.button>
      </.link>
    <%% end %>
    """
  end

  def generate_template_action_buttons() do
    """
    <%%= if can?(@current_scope.user, "metadata.manage") do %>
      <.link patch={~p"/manage/master/#{resource}/\#{item}/edit"}>
        <.icon name="hero-pencil" class="w-4 h-4" />
      </.link>
    <%% end %>

    <%%= if can?(@current_scope.user, "metadata.manage") do %>
      <.link phx-click="delete" phx-value-id={item.id}>
        <.icon name="hero-trash" class="w-4 h-4" />
      </.link>
    <%% end %>
    """
  end

  def list_files_to_update() do
    IO.puts("\n=== Files to Update for Master Data RBAC ===\n")

    for {module_name, _module_title} <- @master_modules do
      IO.puts("Master #{String.capitalize(module_name)} Module:")
      IO.puts("  - lib/voile_web/live/dashboard/master/#{module_name}_live/index.ex")
      IO.puts("  - lib/voile_web/live/dashboard/master/#{module_name}_live/index.html.heex")

      if File.exists?("lib/voile_web/live/dashboard/master/#{module_name}_live/show.ex") do
        IO.puts("  - lib/voile_web/live/dashboard/master/#{module_name}_live/show.ex")
      end

      IO.puts("")
    end
  end

  def generate_implementation_instructions() do
    """

    === RBAC Implementation Instructions ===

    For each Master Data module, follow these steps:

    1. UPDATE INDEX.EX FILE:
       - Add authorization check in mount/3:
         #{generate_mount_check()}

       - If apply_action exists, add checks:
         #{generate_apply_action_checks()}

       - If delete handler exists, add check:
         #{generate_delete_check()}

    2. UPDATE TEMPLATE (.html.heex) FILE:
       - Wrap "New" button:
         #{generate_template_button_check("<resource>")}

       - Wrap Edit/Delete buttons:
         #{generate_template_action_buttons()}

    3. VERIFY:
       - Compile: mix compile
       - Test access with different user roles
       - Confirm buttons show/hide correctly

    === Additional Modules ===

    Metadata Controllers (use plugs):

    ```elixir
    plug VoileWeb.Plugs.Authorization,
      permission: "metadata.manage"
    ```

    Files:
    - lib/voile_web/controllers/vocabulary_controller.ex
    - lib/voile_web/controllers/property_controller.ex
    - lib/voile_web/controllers/resource_class_controller.ex
    - lib/voile_web/controllers/resource_template_controller.ex

    === Permission Mapping ===

    Module                    | Permission Used
    --------------------------|------------------
    Collections               | collections.*
    Items                     | items.*
    Users                     | users.*
    Roles                     | roles.*
    Permissions               | permissions.manage
    Settings/Holidays         | system.settings
    Master Data (all)         | metadata.manage
    Metadata Controllers      | metadata.manage
    GLAM Modules              | collections.* + GLAM-specific

    === Testing Checklist ===

    [ ] Super admin can access everything
    [ ] User without metadata.manage cannot access master data pages
    [ ] Buttons show/hide based on permissions
    [ ] Direct URL access is blocked for unauthorized users
    [ ] Error messages are clear and user-friendly

    """
  end
end

# Run the helper
IO.puts(RBACImplementationHelper.generate_implementation_instructions())
RBACImplementationHelper.list_files_to_update()
