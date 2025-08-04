Mix.Task.run("app.start")

NimbleCSV.define(
  CSVParser,
  separator: ",",
  escape: "\"",
  escape_pattern: ~r/\\./
)

alias Voile.Repo
alias Voile.Schema.Catalog.{Collection, CollectionField}

property_map = %{
  "title" => %{id: 182, local_name: "title", label: "Title", type_value: "text"},
  "sor" => %{
    id: 183,
    local_name: "sor",
    label: "Statement of Responsibility",
    type_value: "textarea"
  },
  "edition" => %{id: 184, local_name: "edition", label: "Edition", type_value: "text"},
  "isbn_issn" => %{id: 185, local_name: "isbn", label: "ISBN/ISSN", type_value: "text"},
  "publisher_id" => %{id: 187, local_name: "publisher", label: "Publisher", type_value: "text"},
  "publish_year" => %{
    id: 188,
    local_name: "publishedYear",
    label: "Published Year",
    type_value: "number"
  },
  "collation" => %{id: 191, local_name: "collation", label: "Collation", type_value: "text"},
  "series_title" => %{
    id: 192,
    local_name: "seriesTitle",
    label: "Series Title",
    type_value: "text"
  },
  "call_number" => %{id: 193, local_name: "callNumber", label: "Call Number", type_value: "text"},
  "classification" => %{
    id: 196,
    local_name: "classification",
    label: "Classification",
    type_value: "text"
  },
  "notes" => %{id: 197, local_name: "notes", label: "Notes", type_value: "textarea"},
  "frequency_id" => %{id: 198, local_name: "frequency", label: "Frequency", type_value: "text"},
  "spec_detail_info" => %{
    id: 199,
    local_name: "specDetailInfo",
    label: "Special Detail Information",
    type_value: "textarea"
  }
}

defmodule Mapper do
  alias Ecto.UUID

  def to_maps(
        [
          biblio_id,
          _gmd_id,
          title,
          sor,
          edition,
          isbn_issn,
          publisher_id,
          publish_year,
          collation,
          series_title,
          call_number,
          _lang,
          _src,
          _place,
          classification,
          notes,
          _img,
          _fa,
          _hide,
          _prom,
          _labels,
          frequency_id,
          spec_detail_info,
          _ct,
          _mt,
          _car,
          _input_date,
          _last_update,
          _uid
        ],
        property_map
      ) do
    raw_uuid = UUID.generate()
    {:ok, id} = UUID.dump(raw_uuid)

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # collection row
    coll = %{
      id: id,
      title: title,
      description: notes || nil,
      thumbnail: nil,
      status: "published",
      access_level: "public",
      old_biblio_id: String.to_integer(biblio_id),
      type_id: nil,
      template_id: nil,
      creator_id: nil,
      unit_id: nil,
      inserted_at: now,
      updated_at: now
    }

    # collect only the properties that actually have data
    values = %{
      "sor" => sor,
      "edition" => edition,
      "isbn_issn" => isbn_issn,
      "publisher_id" => publisher_id,
      "publish_year" => publish_year,
      "collation" => collation,
      "series_title" => series_title,
      "call_number" => call_number,
      "classification" => classification,
      "notes" => notes,
      "frequency_id" => frequency_id,
      "spec_detail_info" => spec_detail_info
    }

    # build many collection_fields rows
    fields =
      values
      |> Enum.filter(fn {_col_name, value} ->
        value not in [nil, "", "\"\""]
      end)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {{col_name, value}, index} ->
        case Map.get(property_map, col_name) do
          nil ->
            []

          prop ->
            gen_uid = UUID.generate()
            {:ok, col_field_id} = UUID.dump(gen_uid)

            [
              %{
                id: col_field_id,
                name: prop.local_name,
                label: prop.label,
                value: to_string(value),
                value_lang: "id",
                type_value: prop.type_value,
                sort_order: index,
                collection_id: id,
                property_id: prop.id,
                inserted_at: now,
                updated_at: now
              }
            ]
        end
      end)

    {coll, fields}
  end
end

csv_path = "scripts/biblio.csv"

File.stream!(csv_path)
|> CSVParser.parse_stream()
|> Stream.map(&Mapper.to_maps(&1, property_map))
|> Stream.chunk_every(200)
|> Enum.each(fn batch ->
  # separate the two lists
  colls = Enum.map(batch, &elem(&1, 0))
  fields = batch |> Enum.flat_map(&elem(&1, 1))

  if length(colls) > 0 do
    Repo.insert_all(Collection.__schema__(:source), colls, on_conflict: :nothing)
  end

  if length(fields) > 0 do
    try do
      Repo.insert_all(CollectionField.__schema__(:source), fields, on_conflict: :nothing)
    rescue
      e in Postgrex.Error ->
        IO.puts("❌ Insertion failed with error: #{Exception.message(e)}")
        IO.inspect(fields, label: "🔍 Problematic fields batch")

        Enum.each(fields, fn row ->
          Enum.each(row, fn {key, value} ->
            if is_binary(value) and String.length(value) > 255 do
              IO.puts(
                "⚠️ Field too long: #{key} => #{String.slice(value, 0..80)}... (#{String.length(value)} chars)"
              )
            end
          end)
        end)

        reraise e, __STACKTRACE__
    end
  end

  IO.puts("Inserted #{length(colls)} collections + #{length(fields)} fields")
end)

IO.puts("✅ Done!")
