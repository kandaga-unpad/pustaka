defmodule VoileWeb.Dashboard.Metaresource.MetaresourceLive do
  use VoileWeb, :live_view_dashboard

  def render(assigns) do
    ~H"""
    <.voile_page_header
      eyebrow={gettext("Metaresource")}
      title={gettext("Metaresource")}
      description={
        gettext(
          "Manage the metadata schemas, vocabularies, and resource templates that describe catalog items."
        )
      }
      icon="hero-tag"
      tone={:brand}
    />

    <.voile_settings_shell
      title={gettext("Metaresource")}
      items={voile_metaresource_nav_items()}
      current_path={@current_path}
    >
      <.voile_section_card title={gettext("Overview")} icon="hero-information-circle" tone={:info}>
        <p class="text-secondary text-sm">
          {gettext(
            "Pick a record type from the left to manage vocabularies, properties, resource classes, and templates."
          )}
        </p>
      </.voile_section_card>
    </.voile_settings_shell>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, gettext("Metaresource"))
      |> assign(:breadcrumb, [
        %{label: gettext("Manage"), path: "/manage"},
        %{label: gettext("Metaresource"), path: nil}
      ])

    {:ok, socket}
  end
end
