defmodule VoileWeb.Api.ErrorJSON do
  def render("401.json", _assigns) do
    %{error: %{message: "Unauthorized", code: 401}}
  end

  def render("403.json", _assigns) do
    %{error: %{message: "Forbidden", code: 403}}
  end

  def render("404.json", _assigns) do
    %{error: %{message: "Not Found", code: 404}}
  end

  def render("500.json", _assigns) do
    %{error: %{message: "Internal Server Error", code: 500}}
  end
end
