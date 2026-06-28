defmodule Voile.Utils.Pagination do
  @moduledoc """
  Safe pagination parameter parsing.

  Prevents crashes from `String.to_integer/1` on malformed input and
  caps `per_page` to avoid resource-exhaustion via oversized page requests.
  """

  @max_per_page 100

  @doc """
  Safely parses a page number from user input.

  Returns a positive integer (default 1). Never raises on bad input.
  """
  def parse_page(value, default \\ 1)

  def parse_page(nil, default), do: default
  def parse_page("", default), do: default

  def parse_page(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> max(n, 1)
      _ -> default
    end
  end

  def parse_page(value, _default) when is_integer(value), do: max(value, 1)
  def parse_page(_, default), do: default

  @doc """
  Safely parses a per-page count from user input.

  Returns a positive integer capped at `#{@max_per_page}`. Never raises.
  """
  def parse_per_page(value, default \\ 20)

  def parse_per_page(nil, default), do: default
  def parse_per_page("", default), do: default

  def parse_per_page(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n |> max(1) |> min(@max_per_page)
      _ -> default
    end
  end

  def parse_per_page(value, _default) when is_integer(value),
    do: value |> max(1) |> min(@max_per_page)

  def parse_per_page(_, default), do: default
end
