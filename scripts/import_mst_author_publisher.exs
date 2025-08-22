Mix.Task.run("app.start")

NimbleCSV.define(
  CSVParser,
  separator: ",",
  escape: "\"",
  escape_pattern: ~r/\\./
)

import Ecto.Query

alias Voile.Repo
alias Voile.Schema.Master.{Creator, Publishers}

batch_size = 500

defmodule CSVProcessor do
  @moduledoc false

  def list_creator_files do
    Path.wildcard("scripts/mst_author*.csv")
  end

  def list_publisher_files do
    Path.wildcard("scripts/mst_publisher*.csv")
  end
end

authority_to_type = fn
  type when is_binary(type) ->
    case String.downcase(String.trim(type)) do
      "p" -> "Person"
      "o" -> "Organization"
      "g" -> "Group"
      "c" -> "Conference"
      "e" -> "Event"
      "i" -> "Institution"
      "pr" -> "Project"
      _ -> "Person"
    end

  _ ->
    "Person"
end

normalize = fn
  nil -> nil
  v -> v |> String.trim() |> (fn s -> if s == "", do: nil, else: s end).()
end

now_ts = NaiveDateTime.utc_now()

# Preload existing names for dedupe
existing_creator_names =
  from(c in Creator, select: c.creator_name)
  |> Repo.all()
  |> Enum.reject(&is_nil/1)
  |> Enum.map(&String.downcase/1)
  |> MapSet.new()

existing_publisher_names =
  from(p in Publishers, select: p.name)
  |> Repo.all()
  |> Enum.reject(&is_nil/1)
  |> Enum.map(&String.downcase/1)
  |> MapSet.new()

creator_files = CSVProcessor.list_creator_files()
publisher_files = CSVProcessor.list_publisher_files()

IO.puts(
  "🔎 Found #{length(creator_files)} creator CSV file(s) and #{length(publisher_files)} publisher CSV file(s)."
)

{creator_inserted_total, creator_skipped_total, creator_skipped_names_total, _seen_creators} =
  Enum.reduce(creator_files, {0, 0, [], existing_creator_names}, fn file,
                                                                    {ins_t, sk_t, names_t, seen} ->
    IO.puts("📄 Processing creators file: #{file}")

    stream =
      File.stream!(file)
      |> CSVParser.parse_stream()
      |> Stream.drop(1)
      |> Stream.map(fn row ->
        [
          author_id,
          author_name,
          _author_year,
          authority_type,
          _auth_list,
          _input_date,
          _last_update
        ] = row

        name = normalize.(author_name)
        {:ok, %{key: author_id, name: name, type: authority_to_type.(authority_type)}}
      end)

    {inserted, skipped, skipped_names, batch, seen2} =
      Enum.reduce(stream, {0, 0, [], [], seen}, fn
        {:ok, %{name: nil}}, acc ->
          acc

        {:ok, %{name: name} = c}, {ins, sk, names, batch_acc, seen_acc} ->
          key = String.downcase(name)

          if MapSet.member?(seen_acc, key) do
            {ins, sk + 1, [name | names], batch_acc, seen_acc}
          else
            seen3 = MapSet.put(seen_acc, key)

            entry = %{
              creator_name: c.name,
              type: c.type,
              creator_contact: nil,
              affiliation: nil,
              inserted_at: now_ts,
              updated_at: now_ts
            }

            batch2 = [entry | batch_acc]

            if length(batch2) >= batch_size do
              Repo.insert_all(Creator.__schema__(:source), Enum.reverse(batch2))
              {ins + length(batch2), sk, names, [], seen3}
            else
              {ins, sk, names, batch2, seen3}
            end
          end
      end)

    # flush remaining
    inserted_final =
      if batch != [] do
        Repo.insert_all(Creator.__schema__(:source), Enum.reverse(batch))
        inserted + length(batch)
      else
        inserted
      end

    IO.puts("✅ Creators file done: +#{inserted_final}, skipped #{skipped}")

    {ins_t + inserted_final, sk_t + skipped, names_t ++ skipped_names, seen2}
  end)

{publisher_inserted_total, publisher_skipped_total, publisher_skipped_names_total, _seen_pubs} =
  Enum.reduce(publisher_files, {0, 0, [], existing_publisher_names}, fn file,
                                                                        {ins_t, sk_t, names_t,
                                                                         seen} ->
    IO.puts("📄 Processing publishers file: #{file}")

    stream =
      File.stream!(file)
      |> CSVParser.parse_stream()
      |> Stream.drop(1)
      |> Stream.map(fn row ->
        [publisher_id, publisher_name | _rest] = row
        {:ok, %{key: publisher_id, name: normalize.(publisher_name)}}
      end)

    {inserted, skipped, skipped_names, batch, seen2} =
      Enum.reduce(stream, {0, 0, [], [], seen}, fn
        {:ok, %{name: nil}}, acc ->
          acc

        {:ok, %{name: name}}, {ins, sk, names, batch_acc, seen_acc} ->
          key = String.downcase(name)

          if MapSet.member?(seen_acc, key) do
            {ins, sk + 1, [name | names], batch_acc, seen_acc}
          else
            seen3 = MapSet.put(seen_acc, key)

            entry = %{
              name: name,
              address: "",
              city: "",
              contact: "",
              inserted_at: now_ts,
              updated_at: now_ts
            }

            batch2 = [entry | batch_acc]

            if length(batch2) >= batch_size do
              Repo.insert_all(Publishers.__schema__(:source), Enum.reverse(batch2))
              {ins + length(batch2), sk, names, [], seen3}
            else
              {ins, sk, names, batch2, seen3}
            end
          end
      end)

    inserted_final =
      if batch != [] do
        Repo.insert_all(Publishers.__schema__(:source), Enum.reverse(batch))
        inserted + length(batch)
      else
        inserted
      end

    IO.puts("✅ Publishers file done: +#{inserted_final}, skipped #{skipped}")

    {ins_t + inserted_final, sk_t + skipped, names_t ++ skipped_names, seen2}
  end)

IO.puts("\n📦 Import summary")
IO.puts("- Creators inserted: #{creator_inserted_total}, skipped: #{creator_skipped_total}")
IO.puts("- Publishers inserted: #{publisher_inserted_total}, skipped: #{publisher_skipped_total}")

if creator_skipped_names_total != [] do
  creator_skipped_names_total
  |> Enum.reverse()
  |> Enum.uniq_by(&String.downcase/1)
  |> Enum.take(50)
  |> Enum.each(&IO.puts("- skipped creator: #{&1}"))
end

if publisher_skipped_names_total != [] do
  publisher_skipped_names_total
  |> Enum.reverse()
  |> Enum.uniq_by(&String.downcase/1)
  |> Enum.take(50)
  |> Enum.each(&IO.puts("- skipped publisher: #{&1}"))
end
