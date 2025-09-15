defmodule VoileWeb.Utils.StringHelper do
  def trim_text(text, max_length \\ 100) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end
end
