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
    abbr: "Faperta",
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

# Populate the User Roles
user_roles = [
  %{
    name: "Super Administrator Dev",
    description: "Super Administrator",
    permissions: %{
      "collection" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "item" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "media" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "system" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "users" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "roles" => %{"create" => true, "read" => true, "update" => true, "delete" => true}
    }
  },
  %{
    name: "Admin Node",
    description: "Full administrative access to node operations",
    permissions: %{
      "users" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "roles" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "collections" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "system" => %{"create" => true, "read" => true, "update" => true, "delete" => true}
    }
  },
  %{
    name: "Koordinator Koleksi",
    description: "Collection coordinator with management access",
    permissions: %{
      "collections" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "users" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Pustakawan (Koordinator)",
    description: "Lead librarian with coordination responsibilities",
    permissions: %{
      "collections" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "circulation" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "users" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Sirkulasi",
    description: "Circulation librarian",
    permissions: %{
      "circulation" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "collections" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Pengolahan (Buku)",
    description: "Book processing librarian",
    permissions: %{
      "books" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "cataloging" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Referensi",
    description: "Reference librarian",
    permissions: %{
      "reference" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "collections" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Sistem (TI)",
    description: "IT systems librarian",
    permissions: %{
      "system" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "users" => %{"create" => false, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Pengolahan (ETD)",
    description: "Electronic thesis and dissertation processing librarian",
    permissions: %{
      "etd" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "cataloging" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Pustakawan (General)",
    description: "General librarian",
    permissions: %{
      "collections" => %{"create" => false, "read" => true, "update" => false, "delete" => false},
      "circulation" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Koleksi Populer",
    description: "Popular collection librarian",
    permissions: %{
      "popular_collections" => %{
        "create" => true,
        "read" => true,
        "update" => true,
        "delete" => false
      },
      "circulation" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Arsiparis (Koordinator)",
    description: "Head archivist",
    permissions: %{
      "archives" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "users" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Arsiparis",
    description: "Archivist",
    permissions: %{
      "archives" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Kurator Museum",
    description: "Museum curator",
    permissions: %{
      "museum" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "exhibitions" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Kurator Galeri",
    description: "Gallery curator",
    permissions: %{
      "gallery" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "exhibitions" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  }
]

for role <- user_roles do
  Voile.Schema.Accounts.create_user_role(role)
end
