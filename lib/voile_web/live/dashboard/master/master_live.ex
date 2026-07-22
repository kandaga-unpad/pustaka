defmodule VoileWeb.Dashboard.Master.MasterLive do
  use VoileWeb, :live_view_dashboard
  alias VoileWeb.Auth.Authorization

  def render(assigns) do
    ~H"""
    <.voile_page_header
      eyebrow={gettext("Master data")}
      title={gettext("Master data")}
      description={gettext("Manage the controlled-vocabulary records that catalog items reference.")}
      icon="hero-circle-stack"
      tone={:brand}
    />

    <.voile_settings_shell
      title={gettext("Master data")}
      items={voile_master_nav_items()}
      current_path={@current_path}
    >
      <.voile_section_card title={gettext("Overview")} icon="hero-information-circle" tone={:info}>
        <p class="text-secondary text-sm">
          {gettext(
            "Pick a record type from the left to manage the creators, publishers, locations, and other reference data used across the catalog."
          )}
        </p>
      </.voile_section_card>
    </.voile_settings_shell>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    unless Authorization.can?(user, "metadata.manage") do
      socket =
        socket
        |> put_flash(
          :error,
          gettext("Access Denied: You don't have permission to access this page")
        )
        |> push_navigate(to: ~p"/manage")

      {:ok, socket}
    else
      socket =
        socket
        |> assign(:page_title, gettext("Master data"))
        |> assign(:breadcrumb, [
          %{label: gettext("Manage"), path: "/manage"},
          %{label: gettext("Master data"), path: nil}
        ])

      {:ok, socket}
    end
  end
end
