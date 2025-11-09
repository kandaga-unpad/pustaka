defmodule VoileWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use VoileWeb, :html

  # If you want to customize your error pages,
  # uncomment the embed_templates/1 call below
  # and add pages to the error directory:
  #
  #   * lib/voile_web/controllers/error_html/404.html.heex
  #   * lib/voile_web/controllers/error_html/500.html.heex
  #
  embed_templates "error_html/*"

  # The default is to render a plain text page based on
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def render(template, assigns) do
    # Add defaults
    assigns =
      assigns
      |> Enum.into(%{})
      |> Map.put_new(:current_scope, nil)
      |> Map.put_new(:current_user, nil)
      |> Map.put_new(:flash, %{})
      |> Map.put_new(:app_main_color, "#9333ea")
      |> Map.put_new(:app_secondary_color, "#7c3aed")
      |> Map.put_new(:page_title, get_page_title(template))

    # embed_templates creates template functions, call them via __MODULE__
    template_atom = template |> String.replace(".", "_") |> String.to_atom()

    if function_exported?(__MODULE__, template_atom, 1) do
      apply(__MODULE__, template_atom, [assigns])
    else
      Phoenix.Controller.status_message_from_template(template)
    end
  end

  defp get_page_title("404.html"), do: "Page Not Found"
  defp get_page_title("500.html"), do: "Internal Server Error"
  defp get_page_title("503.html"), do: "Service Unavailable"
  defp get_page_title(_), do: "Error"
end
