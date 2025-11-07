# i18n Quick Reference

## Quick Start

### 1. Use gettext in templates
```heex
<h1>{gettext("Welcome")}</h1>
<button>{gettext("Save")}</button>
```

### 2. Use with variables
```heex
<p>{gettext("Hello, %{name}!", name: @user.name)}</p>
```

### 3. Add locale switcher
```heex
<.locale_switcher current_path={@current_path} />
```

## Common Translations

| English | Indonesian (Bahasa) | Usage |
|---------|---------------------|-------|
| Save | Simpan | `gettext("Save")` |
| Cancel | Batal | `gettext("Cancel")` |
| Delete | Hapus | `gettext("Delete")` |
| Edit | Ubah | `gettext("Edit")` |
| Create | Buat | `gettext("Create")` |
| Search | Cari | `gettext("Search")` |
| Submit | Kirim | `gettext("Submit")` |
| Back | Kembali | `gettext("Back")` |
| Next | Berikutnya | `gettext("Next")` |
| Yes | Ya | `gettext("Yes")` |
| No | Tidak | `gettext("No")` |
| Home | Beranda | `gettext("Home")` |
| Dashboard | Dasbor | `gettext("Dashboard")` |
| Profile | Profil | `gettext("Profile")` |
| Settings | Pengaturan | `gettext("Settings")` |
| Sign in | Masuk | `gettext("Sign in")` |
| Sign out | Keluar | `gettext("Sign out")` |
| Register | Daftar | `gettext("Register")` |
| Forgot password? | Lupa kata sandi? | `gettext("Forgot password?")` |

## Common Messages

| English | Indonesian | Usage |
|---------|-----------|-------|
| Are you sure? | Anda yakin? | `gettext("Are you sure?")` |
| Successfully created | Berhasil dibuat | `gettext("Successfully created")` |
| Successfully updated | Berhasil diperbarui | `gettext("Successfully updated")` |
| Successfully deleted | Berhasil dihapus | `gettext("Successfully deleted")` |
| An error occurred | Terjadi kesalahan | `gettext("An error occurred")` |
| Loading... | Memuat... | `gettext("Loading...")` |
| No results found | Tidak ada hasil ditemukan | `gettext("No results found")` |
| No data available | Tidak ada data tersedia | `gettext("No data available")` |

## Validation Errors

| English | Indonesian | Usage |
|---------|-----------|-------|
| can't be blank | tidak boleh kosong | Auto-translated by Ecto |
| has already been taken | sudah digunakan | Auto-translated by Ecto |
| is invalid | tidak valid | Auto-translated by Ecto |
| must be accepted | harus disetujui | Auto-translated by Ecto |
| has invalid format | format tidak valid | Auto-translated by Ecto |

## Commands

```bash
# Extract new translatable strings
mix gettext.extract

# Merge with existing translations
mix gettext.merge priv/gettext --locale id
mix gettext.merge priv/gettext --locale en

# Check for missing translations
mix gettext.extract --check-up-to-date
```

## File Locations

- **Configuration**: `config/config.exs`
- **Indonesian translations**: `priv/gettext/id/LC_MESSAGES/default.po`
- **English translations**: `priv/gettext/en/LC_MESSAGES/default.po`
- **Error translations**: `priv/gettext/{id,en}/LC_MESSAGES/errors.po`
- **Locale plug**: `lib/voile_web/plugs/locale.ex`
- **Locale utilities**: `lib/voile_web/utils/locale.ex`
- **Gettext backend**: `lib/voile_web/gettext.ex`

## Locale Utilities

```elixir
# Get current locale
VoileWeb.Utils.Locale.get_locale()
# => "id" or "en"

# Set locale
VoileWeb.Utils.Locale.put_locale("en")

# Get locale name
VoileWeb.Utils.Locale.locale_name("id")
# => "Bahasa Indonesia"

# Get all locales
VoileWeb.Utils.Locale.all_locales()
# => [%{code: "id", name: "Bahasa Indonesia", flag: "🇮🇩"}, ...]
```

## URL Examples

- Switch to Indonesian: `?locale=id`
- Switch to English: `?locale=en`
- Examples:
  - `http://localhost:4000?locale=id`
  - `http://localhost:4000/dashboard?locale=en`

## Tips

1. **Always** wrap user-facing text in `gettext()`
2. **Use variables** for dynamic content: `gettext("Hello, %{name}!", name: user.name)`
3. **Domains** organize translations: `dgettext("errors", "can't be blank")`
4. **Test** both locales before deploying
5. **Default locale is Indonesian** - translations fall back to `msgid` if missing

## Example LiveView

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <h1>{gettext("Products")}</h1>
    <button phx-click="create">{gettext("Create")}</button>
    <.locale_switcher current_path={@current_path} />
    """
  end

  def handle_event("create", _, socket) do
    {:noreply, put_flash(socket, :info, gettext("Successfully created"))}
  end
end
```
