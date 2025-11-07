defmodule Client.Storage.Behaviour do
  @moduledoc """
  Behaviour for storage adapters.
  """

  @callback upload(upload :: map(), opts :: keyword()) :: {:ok, String.t()} | {:error, any()}
  @callback delete(file_url :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, any()}
  @callback presign(file_key :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, any()}
end
