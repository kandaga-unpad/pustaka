defmodule VoileWeb.API.ErrorJSON do
  def render("401.json", assigns) do
    %{error: %{message: "Unauthorized", code: 401, details: assigns[:message] || nil}}
  end

  def render("403.json", assigns) do
    %{error: %{message: "Forbidden", code: 403, details: assigns[:message] || nil}}
  end

  def render("404.json", assigns) do
    %{error: %{message: "Not Found", code: 404, details: assigns[:message] || nil}}
  end

  def render("500.json", assigns) do
    %{error: %{message: "Internal Server Error", code: 500, details: assigns[:message] || nil}}
  end
end
