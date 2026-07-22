defmodule Mix.Tasks.Voile.Update do
  @shortdoc "Update data from SLiMS CSV delta exports (masters + biblio + items)"

  @moduledoc """
  Delta update task for importing new/changed data from SLiMS.

  Designed for incremental updates: place only the new CSV files (exported
  since the last import) into the standard csv_data folders, then run:

      mix voile.update

  This runs three stages in order:
  1. **Master data** (authors, publishers) — safe to re-run, dedup by name
  2. **Bibliography** (collections) — safe to re-run, dedup by {unit_id, old_biblio_id}
  3. **Items** — continues item_code numbering from current DB state (no collisions)

  ## Options

      mix voile.update                       # Default: masters + biblio + items, skip images
      mix voile.update --with-images         # Download cover images during biblio import
      mix voile.update --batch-size 2000     # Custom batch size (default 500)
      mix voile.update --skip-masters        # Skip author/publisher import
      mix voile.update --skip-biblio         # Skip bibliography import

  ## CSV file placement

  Place CSV files in these directories (delete old files first):

      scripts/csv_data/mst/        # mst_author*.csv, mst_publisher*.csv
      scripts/csv_data/biblio/      # biblio_*.csv
      scripts/csv_data/items/       # item_*.csv

  In production (container):
      /app/scripts/csv_data/
  """

  use Mix.Task

  alias Voile.Migration.{MasterImporter, BiblioImporter, ItemImporter}

  @default_batch_size 500

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          batch_size: :integer,
          with_images: :boolean,
          skip_masters: :boolean,
          skip_biblio: :boolean,
          skip_items: :boolean
        ],
        aliases: [
          b: :batch_size
        ]
      )

    Mix.Task.run("app.start", [])

    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    skip_images = !Keyword.get(opts, :with_images, false)

    skip_masters = Keyword.get(opts, :skip_masters, false)
    skip_biblio = Keyword.get(opts, :skip_biblio, false)
    skip_items = Keyword.get(opts, :skip_items, false)

    IO.puts("=" |> String.duplicate(60))
    IO.puts("🔄 VOILE DELTA UPDATE")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("  Batch size: #{batch_size}")
    IO.puts("  Images: #{if skip_images, do: "skip", else: "download"}")
    IO.puts("")

    steps =
      []
      |> maybe_add_step(
        not skip_masters,
        {"Master Data (Authors & Publishers)",
         fn ->
           MasterImporter.import_all(batch_size)
         end}
      )
      |> maybe_add_step(
        not skip_biblio,
        {"Bibliography Data",
         fn ->
           BiblioImporter.import_all(batch_size, skip_images)
         end}
      )
      |> maybe_add_step(
        not skip_items,
        {"Item Data",
         fn ->
           ItemImporter.import_all(batch_size)
         end}
      )

    if Enum.empty?(steps) do
      IO.puts("⚠️ All stages skipped. Nothing to do.")
    else
      IO.puts("📋 Update plan:")

      steps
      |> Enum.with_index(1)
      |> Enum.each(fn {{name, _}, i} ->
        IO.puts("  #{i}. #{name}")
      end)

      IO.puts("")

      total_start = System.monotonic_time(:millisecond)

      results =
        Enum.map(steps, fn {name, import_func} ->
          IO.puts("\n📦 Updating #{name}...")
          start_time = System.monotonic_time(:millisecond)

          result = import_func.()

          duration = System.monotonic_time(:millisecond) - start_time
          IO.puts("✅ #{name} completed in #{Float.round(duration / 1000, 1)}s")

          {name, result}
        end)

      total_duration = System.monotonic_time(:millisecond) - total_start

      IO.puts("\n" <> ("=" |> String.duplicate(60)))
      IO.puts("📊 UPDATE SUMMARY")
      IO.puts("=" |> String.duplicate(60))

      Enum.each(results, fn {name, result} ->
        IO.puts("\n#{name}:")

        case result do
          %{inserted: inserted} when is_map(result) ->
            skipped = Map.get(result, :skipped, 0)
            IO.puts("  Inserted: #{inserted}")
            IO.puts("  Skipped: #{skipped}")

          %{stats: stats} when is_map(stats) ->
            Enum.each(stats, fn {key, value} ->
              IO.puts("  #{format_label(key)}: #{value}")
            end)

          _ ->
            IO.puts("  #{inspect(result)}")
        end
      end)

      IO.puts("\n⏱️ Total time: #{Float.round(total_duration / 1000, 1)}s")
      IO.puts("=" |> String.duplicate(60))
    end
  end

  defp maybe_add_step(steps, true, step), do: steps ++ [step]
  defp maybe_add_step(steps, false, _step), do: steps

  defp format_label(key) when is_atom(key), do: key |> Atom.to_string() |> String.capitalize()
  defp format_label(key), do: to_string(key) |> String.capitalize()
end
