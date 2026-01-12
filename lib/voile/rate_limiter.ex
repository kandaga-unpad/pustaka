defmodule Voile.RateLimiter do
  @moduledoc """
  Rate limiter using Hammer 7.x with ETS backend.
  """
  use Hammer, backend: :ets
end
