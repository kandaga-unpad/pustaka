# Dashboard i18n Translation Guide

## Quick Translation Pattern

### For `.ex` Files (LiveView modules)
Replace hardcoded strings with `gettext()`:

```elixir
# Before
assign(:page_title, "Circulation History")

# After  
assign(:page_title, gettext("Circulation History"))
```

### For `.heex` Template Files
Wrap display text in `{gettext()}`:

```heex
<!-- Before -->
<h1>Listing Collections</h1>
<.button>New Collection</.button>
<span>Results</span>

<!-- After -->
<h1>{gettext("Listing Collections")}</h1>
<.button>{gettext("New Collection")}</.button>
<span>{gettext("Results")}</span>
```

## Common Dashboard Terms - Quick Reference

### Navigation & Actions
- Back → "Kembali"
- Save → "Simpan"  
- Cancel → "Batal"
- Delete → "Hapus"
- Edit → "Ubah"
- Create → "Buat"
- New → "Baru"
- Import → "Impor"
- Export → "Ekspor"
- Filter → "Filter" (same)
- Search → "Cari"
- Clear → "Bersihkan"
- Apply → "Terapkan"
- Reset → "Atur Ulang"
- Submit → "Kirim"
- Close → "Tutup"
- View → "Lihat"
- Download → "Unduh"
- Upload → "Unggah"

### Collections & Items
- Collection → "Koleksi"
- Collections → "Koleksi"
- Item → "Item"
- Items → "Item"
- Catalog → "Katalog"
- Listing Collections → "Daftar Koleksi"
- New Collection → "Koleksi Baru"
- Edit Collection → "Ubah Koleksi"
- Collection Details → "Detail Koleksi"
- Total Collections → "Total Koleksi"
- Total Items → "Total Item"

### Library/Circulation Terms
- Circulation → "Sirkulasi"
- Circulation History → "Riwayat Sirkulasi"
- Transaction → "Transaksi"
- Reservation → "Reservasi"
- Fine → "Denda"
- Requisition → "Permintaan"
- Borrow → "Pinjam"
- Return → "Kembalikan"
- Overdue → "Terlambat"
- Available → "Tersedia"
- Borrowed → "Dipinjam"
- Reserved → "Direservasi"

### GLAM Types
- Gallery → "Galeri"
- Library → "Perpustakaan"
- Archive → "Arsip"
- Museum → "Museum"

### Status & States
- Active → "Aktif"
- Inactive → "Tidak Aktif"
- Pending → "Tertunda"
- Approved → "Disetujui"
- Rejected → "Ditolak"
- Draft → "Draf"
- Published → "Dipublikasikan"
- Archived → "Diarsipkan"

### Common UI Elements
- Results → "Hasil"
- Loading → "Memuat"
- Loading... → "Memuat..."
- No results found → "Tidak ada hasil ditemukan"
- Page → "Halaman"
- of → "dari"
- Showing → "Menampilkan"
- Search... → "Cari..."
- Filter by → "Filter berdasarkan"
- Sort by → "Urutkan berdasarkan"
- All → "Semua"
- Select → "Pilih"
- Selected → "Dipilih"
- Clear search → "Hapus pencarian"
- Press / to search → "Tekan / untuk mencari"

### Forms & Validation
- Required → "Wajib"
- Optional → "Opsional"
- Title → "Judul"
- Description → "Deskripsi"
- Name → "Nama"
- Code → "Kode"
- Status → "Status"
- Type → "Tipe"
- Location → "Lokasi"
- Date → "Tanggal"
- Time → "Waktu"
- From → "Dari"
- To → "Hingga"
- Notes → "Catatan"
- Attachment → "Lampiran"
- File → "Berkas"

### Messages
- Success → "Berhasil"
- Error → "Kesalahan"
- Warning → "Peringatan"
- Info → "Informasi"
- Are you sure? → "Apakah Anda yakin?"
- This action cannot be undone → "Tindakan ini tidak dapat dibatalkan"
- Successfully created → "Berhasil dibuat"
- Successfully updated → "Berhasil diperbarui"
- Successfully deleted → "Berhasil dihapus"
- Failed to create → "Gagal membuat"
- Failed to update → "Gagal memperbarui"
- Failed to delete → "Gagal menghapus"

### Permissions & Roles
- Permission → "Izin"
- Role → "Peran"
- Admin → "Admin"
- Staff → "Staf"
- Member → "Anggota"
- You don't have permission → "Anda tidak memiliki izin"
- Viewing collections based on your role → "Melihat koleksi berdasarkan peran Anda"

## Step-by-Step Translation Workflow

### 1. Extract New Strings
```bash
mix gettext.extract --merge
```

### 2. Find Untranslated Strings
```bash
# Find empty msgstr in Indonesian file
grep -A 1 'msgid' priv/gettext/id/LC_MESSAGES/default.po | grep 'msgstr ""'
```

### 3. Add Indonesian Translations
Edit `priv/gettext/id/LC_MESSAGES/default.po` and add translations for empty `msgstr ""` entries.

### 4. Add English Translations  
Edit `priv/gettext/en/LC_MESSAGES/default.po` - usually `msgstr` = `msgid` for English.

### 5. Remove Duplicates
```bash
mix expo.msguniq priv/gettext/id/LC_MESSAGES/default.po --output-file priv/gettext/id/LC_MESSAGES/default.po
mix expo.msguniq priv/gettext/en/LC_MESSAGES/default.po --output-file priv/gettext/en/LC_MESSAGES/default.po
```

### 6. Compile & Test
```bash
mix compile
mix phx.server
```

## Priority Files to Translate

### High Priority (User-Facing)
1. ✅ `lib/voile_web/live/dashboard/dashboard_live.ex`
2. ✅ `lib/voile_web/live/dashboard/catalog/index.ex`
3. ✅ `lib/voile_web/components/voile_dashboard_components.ex`
4. ⏳ `lib/voile_web/live/dashboard/catalog/collection_live/index.html.heex` (in progress)
5. `lib/voile_web/live/dashboard/catalog/item_live/index.html.heex`
6. `lib/voile_web/live/dashboard/glam/index.ex`
7. `lib/voile_web/live/dashboard/glam/library/circulation/index.ex`

### Medium Priority (Admin Features)
- Master data pages (creator, publisher, location, etc.)
- Settings pages
- Metaresource pages

### Low Priority (Advanced Features)
- Import/export wizards
- Detailed forms
- Advanced filters

## Bulk Translation Tips

### Use Search & Replace in VS Code
For common patterns, use Find & Replace with regex:

**Find:** `<\.button>(.*?)</\.button>`
**Replace:** `<.button>{gettext("$1")}</.button>`

**Find:** `<span>(Active|Inactive|Pending)</span>`
**Replace:** `<span>{gettext("$1")}</span>`

### Translate by Component Type

**Headers:**
```heex
<.header>Page Title</.header>
→ <.header>{gettext("Page Title")}</.header>
```

**Buttons:**
```heex
<.button>Action</.button>
→ <.button>{gettext("Action")}</.button>
```

**Labels:**
```heex
<span class="label">Label Text</span>
→ <span class="label">{gettext("Label Text")}</span>
```

## Current Progress

✅ **Completed:**
- Main dashboard
- Catalog overview
- Dashboard components (search widget, menu bar)
- Core components (already done)
- Main layout (already done)
- Homepage (already done)

⏳ **In Progress:**
- Collection listing page

📋 **Remaining:**
- Collection details/show page
- Collection form component
- Item listing page
- Item details/show page
- Item form component
- GLAM section (Gallery, Library, Archive, Museum)
- Library circulation (transactions, reservations, fines, requisitions)
- Master data pages (creator, publisher, locations, topics, places, frequencies, member types)
- Settings pages
- Metaresource pages

## Translation File Locations

- **Indonesian:** `priv/gettext/id/LC_MESSAGES/default.po`
- **English:** `priv/gettext/en/LC_MESSAGES/default.po`
- **Errors:** `priv/gettext/{locale}/LC_MESSAGES/errors.po`

## Useful Commands

```bash
# Extract all translatable strings
mix gettext.extract

# Merge into existing .po files
mix gettext.merge priv/gettext

# Extract and merge in one command
mix gettext.extract --merge

# Remove duplicate entries
mix expo.msguniq priv/gettext/id/LC_MESSAGES/default.po --output-file priv/gettext/id/LC_MESSAGES/default.po

# Compile (will fail if duplicates or errors exist)
mix compile

# Check for untranslated strings
grep 'msgstr ""' priv/gettext/id/LC_MESSAGES/default.po
```

## Notes

- Always use `{gettext()}` in templates, not `<%= gettext() %>`
- For interpolation: `gettext("Hello %{name}!", name: @user.name)`
- For pluralization: `ngettext("1 item", "%{count} items", @count)`
- Keep `msgid` in English for consistency
- Test both Indonesian (default) and English locales
- Locale switcher is in the top-right navigation
