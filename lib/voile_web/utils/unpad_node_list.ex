defmodule VoileWeb.Utils.UnpadNodeList do
  def unpad_node_list() do
    [
      %{
        id: 110,
        namaFakultas: "Fakultas Hukum",
        singkatan: "fh"
      },
      %{
        id: 120,
        namaFakultas: "Fakultas Ekonomi & Bisnis",
        singkatan: "feb"
      },
      %{
        id: 130,
        namaFakultas: "Fakultas Kedokteran",
        singkatan: "fk"
      },
      %{
        id: 140,
        namaFakultas: "Fakultas Matematika & IPA",
        singkatan: "fmipa"
      },
      %{
        id: 150,
        namaFakultas: "Fakultas Pertanian",
        singkatan: "faperta"
      },
      %{
        id: 160,
        namaFakultas: "Fakultas Kedokteran Gigi",
        singkatan: "fkg"
      },
      %{
        id: 170,
        namaFakultas: "Fakultas Ilmu Sosial & Ilmu Politik",
        singkatan: "fisip"
      },
      %{
        id: 180,
        namaFakultas: "Fakultas Ilmu Budaya",
        singkatan: "fib"
      },
      %{
        id: 190,
        namaFakultas: "Fakultas Psikologi",
        singkatan: "fapsi"
      },
      %{
        id: 200,
        namaFakultas: "Fakultas Peternakan",
        singkatan: "fapet"
      },
      %{
        id: 210,
        namaFakultas: "Fakultas Ilmu Komunikasi",
        singkatan: "fikom"
      },
      %{
        id: 220,
        namaFakultas: "Fakultas Keperawatan",
        singkatan: "fkep"
      },
      %{
        id: 230,
        namaFakultas: "Fakultas Perikanan & Ilmu Kelautan",
        singkatan: "fpik"
      },
      %{
        id: 240,
        namaFakultas: "Fakultas Teknologi Industri Pertanian",
        singkatan: "ftip"
      },
      %{
        id: 250,
        namaFakultas: "Sekolah Pascasarjana",
        singkatan: "sps"
      },
      %{
        id: 260,
        namaFakultas: "Fakultas Farmasi",
        singkatan: "farmasi"
      },
      %{
        id: 270,
        namaFakultas: "Fakultas Teknik Geologi",
        singkatan: "ftg"
      },
      %{
        id: 500,
        namaFakultas: "Unpad Press",
        singkatan: "unpad_press"
      }
    ]
  end

  def get_node_by_id(id) do
    unpad_node_list()
    |> Enum.find(fn node -> node.id == id end)
  end

  def get_node_by_abbr(abbr) do
    unpad_node_list()
    |> Enum.find(fn node -> node.singkatan == abbr end)
  end
end
