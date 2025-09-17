# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Voile.Repo.insert!(%Voile.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Voile.Schema.Metadata

# Populate the Vocabulary
vocab = [
  %{
    namespace_url: "http://purl.org/dc/terms/",
    prefix: "dcterms",
    label: "Dublin Core",
    information: "Basic resource metadata (DCMI Metadata Terms)"
  },
  %{
    namespace_url: "http://purl.org/dc/dcmitype/",
    prefix: "dctype",
    label: "Dublin Core Type",
    information: "Basic resource types (DCMI Type Vocabulary)"
  },
  %{
    namespace_url: "http://purl.org/ontology/bibo/",
    prefix: "bibo",
    label: "Bibliographic Ontology",
    information: "Bibliographic metadata (BIBO)"
  },
  %{
    namespace_url: "http://xmlns.com/foaf/0.1/",
    prefix: "foaf",
    label: "Friend of a Friend",
    information: "Relationships between people and organizations (FOAF)"
  },
  %{
    namespace_url: "https://kandaga.unpad.ac.id/vocab/book/",
    prefix: "kandaga_book",
    label: "Kandaga Book Vocabulary",
    information: "Vocabulary for Kandaga book metadata"
  }
]

for vocabulary <- vocab do
  Metadata.create_vocabulary(vocabulary)
end

# Populate the Node List
node_list = [
  %{
    name: "Fakultas Hukum",
    abbr: "FH",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Ekonomi dan Bisnis",
    abbr: "FEB",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Kedokteran",
    abbr: "FK",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Matematika dan Ilmu Pengetahuan Alam",
    abbr: "FMIPA",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Pertanian",
    abbr: "FAPERTA",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Kedokteran Gigi",
    abbr: "FKG",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Ilmu Sosial dan Ilmu Politik",
    abbr: "FISIP",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Ilmu Budaya",
    abbr: "FIB",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Psikologi",
    abbr: "FAPSI",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Peternakan",
    abbr: "FAPET",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Ilmu Komunikasi",
    abbr: "FIKOM",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Keperawatan",
    abbr: "FKEP",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Perikanan dan Ilmu Kelautan",
    abbr: "FPIK",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Teknologi Industri Pertanian",
    abbr: "FTIP",
    description: nil,
    image: nil
  },
  %{
    name: "Sekolah Pascasarjana",
    abbr: "SPS",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Farmasi",
    abbr: "FARMASI",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Teknik Geologi",
    abbr: "FTG",
    description: nil,
    image: nil
  },
  %{
    name: "Perpustakaan Pangandaran",
    abbr: "Pangandaran",
    description: nil,
    image: nil
  },
  %{
    name: "Perpustakaan Garut",
    abbr: "Garut",
    description: nil,
    image: nil
  },
  %{
    name: "Perpustakaan Pusat",
    abbr: "Kandaga",
    description: nil,
    image: nil
  },
  %{
    name: "Fakultas Vokasi",
    abbr: "Vokasi",
    description: nil,
    image: nil
  }
]

for node <- node_list do
  case Voile.Repo.get_by(Voile.Schema.System.Node, name: node.name) do
    nil -> Voile.Schema.System.create_node(node)
    _existing -> IO.puts("Node #{node.name} already exists, skipping...")
  end
end

# Load GLAM Collections (Gallery, Library, Archive, Museum)
IO.puts("🎨 Loading GLAM Collections...")
Code.require_file("priv/repo/seeds/glams.exs")
