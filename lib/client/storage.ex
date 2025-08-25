defmodule Client.Storage do
  @moduledoc """
  Main storage interface that delegates to configured storage adapter.
  """

  @default_adapter Application.compile_env(:voile, :storage_adapter, Client.Storage.Local)

  @doc """
  Upload a file using the configured storage adapter.

  ## Options
    * `:adapter` - Override the default storage adapter
    * `:folder` - Specify upload folder (e.g., "thumbnails", "attachments")
    * `:generate_filename` - Whether to generate a unique filename (default: true)
    * `:preserve_extension` - Whether to preserve original file extension (default: true)
  """
  def upload(file_params, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, @default_adapter)
    adapter.upload(file_params, opts)
  end

  @doc """
  Delete a file using the configured storage adapter.
  """
  def delete(file_url, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, @default_adapter)
    adapter.delete(file_url, opts)
  end
end
