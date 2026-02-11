# Internationalization (i18n) Guide for Voile

This guide explains how to use internationalization (i18n) in the Voile Phoenix application.

## Overview

Voile uses Phoenix's Gettext library for internationalization with:
- **Default locale**: Indonesian (`id`)
- **Supported locales**: Indonesian (`id`) and English (`en`)

## Configuration

The i18n configuration is in `config/config.exs`:

```elixir
config :voile, VoileWeb.Gettext,
  locales: ~w(id en),
  default_locale: "id"
```

## How It Works

### 1. Locale Detection

The locale is automatically detected in the following order:
1. Query parameter (`?locale=id` or `?locale=en`)
2. Session (persisted after first selection)
3. `Accept-Language` HTTP header
4. Default locale (Indonesian)

### 2. Locale Switching

Users can switch languages by:
- Using the locale switcher component
- Adding `?locale=en` or `?locale=id` to any URL

## Usage in Code

### Basic Translation

In LiveViews, Controllers, and Components:

```elixir
# Simple translation
gettext("Save")  # Returns: "Simpan" (Indonesian) or "Save" (English)

# Translation with variables
gettext("Hello, %{name}!", name: "John")
```

### In Templates (HEEx)

```heex
<!-- Simple text -->
<h1>{gettext("Welcome")}</h1>

<!-- In attributes -->
<button title={gettext("Save")}>{gettext("Save")}</button>

<!-- With variables -->
<p>{gettext("Showing %{count} items", count: @total)}</p>
```

### Domain-Based Translation

Use domains to organize translations by context:

```elixir
# Using the "errors" domain (for validation errors)
dgettext("errors", "can't be blank")

# Using the "default" domain (for UI text)
dgettext("default", "Save")
```

### Plural Translations

```elixir
ngettext(
  "One item",
  "%{count} items",
  count
)
```

## Translation Files

Translation files are in `priv/gettext/`:

```
priv/gettext/
├── id/                        # Indonesian translations
│   └── LC_MESSAGES/
│       ├── default.po        # UI translations
│       └── errors.po         # Validation errors
├── en/                        # English translations
│   └── LC_MESSAGES/
│       ├── default.po
│       └── errors.po
└── errors.pot                # Template file
```

### Translation File Format

```po
## Comment explaining the source
msgid "Save"
msgstr "Simpan"

## With variables
msgid "Hello, %{name}!"
msgstr "Halo, %{name}!"

## Plural forms
msgid "One item"
msgid_plural "%{count} items"
msgstr[0] "Satu item"
msgstr[1] "%{count} item"
```

## Common Translations

We've pre-translated common UI elements in `default.po`:

### Actions
- Save → Simpan
- Cancel → Batal
- Delete → Hapus
- Edit → Ubah
- Create → Buat
- Submit → Kirim
- Search → Cari

### Authentication
- Sign in → Masuk
- Sign up → Daftar
- Sign out → Keluar
- Forgot password? → Lupa kata sandi?
- Reset password → Atur ulang kata sandi

### Navigation
- Home → Beranda
- Dashboard → Dasbor
- Profile → Profil
- Settings → Pengaturan

### Messages
- Are you sure? → Anda yakin?
- Successfully created → Berhasil dibuat
- Successfully updated → Berhasil diperbarui
- Successfully deleted → Berhasil dihapus
- An error occurred → Terjadi kesalahan

## Using the Locale Switcher Component

Add the locale switcher to your layout or navigation:

```heex
<!-- In a navbar -->
<nav>
  <.locale_switcher current_path={@current_path} />
</nav>

<!-- With custom class -->
<.locale_switcher class="my-4" current_path={@current_path} />
```

The switcher automatically:
- Shows the current locale with flag emoji
- Provides a dropdown to switch languages
- Persists the selection in the session
- Updates the URL with the locale parameter

## Utility Functions

Use `VoileWeb.Utils.Locale` for locale management:

```elixir
# Get current locale
VoileWeb.Utils.Locale.get_locale()  # Returns: "id" or "en"

# Set locale
VoileWeb.Utils.Locale.put_locale("en")

# Get locale display name
VoileWeb.Utils.Locale.locale_name("id")  # Returns: "Bahasa Indonesia"

# Get locale flag
VoileWeb.Utils.Locale.locale_flag("id")  # Returns: "🇮🇩"

# Get all locales
VoileWeb.Utils.Locale.all_locales()
# Returns: [
#   %{code: "id", name: "Bahasa Indonesia", flag: "🇮🇩"},
#   %{code: "en", name: "English", flag: "🇬🇧"}
# ]
```

## Adding New Translations

### 1. Extract translatable strings

Run this command to find all translatable strings in your code:

```bash
mix gettext.extract
```

### 2. Merge with existing translations

```bash
mix gettext.merge priv/gettext --locale id
mix gettext.merge priv/gettext --locale en
```

### 3. Add translations manually

Edit the `.po` files in `priv/gettext/id/LC_MESSAGES/` and `priv/gettext/en/LC_MESSAGES/`:

```po
## In your LiveView
msgid "New translation"
msgstr "Terjemahan baru"
```

### 4. Compile translations

Translations are automatically compiled when you start your server, but you can manually compile:

```bash
mix gettext.compile
```

## Best Practices

1. **Always use gettext** for user-facing text, never hardcode strings
   ```elixir
   # ❌ Bad
   <button>Save</button>
   
   # ✅ Good
   <button>{gettext("Save")}</button>
   ```

2. **Use domains** to organize translations
   ```elixir
   # For UI elements
   dgettext("default", "Save")
   
   # For errors
   dgettext("errors", "can't be blank")
   ```

3. **Provide context in comments**
   ```po
   ## Button to save user profile
   msgid "Save"
   msgstr "Simpan"
   ```

4. **Use variables** for dynamic content
   ```elixir
   gettext("Welcome, %{name}!", name: user.name)
   ```

5. **Test both locales** to ensure translations work correctly

6. **Keep translations concise** - Indonesian tends to be longer than English

## Examples

### Example 1: LiveView with Translations

```elixir
defmodule VoileWeb.ProductLive.Index do
  use VoileWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Products"))
     |> assign(:empty_message, gettext("No products found"))}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>{@page_title}</h1>
      
      <button phx-click="create">
        {gettext("Create Product")}
      </button>
      
      <%= if @products == [] do %>
        <p>{@empty_message}</p>
      <% end %>
      
      <.locale_switcher current_path={@current_path} />
    </div>
    """
  end
end
```

### Example 2: Flash Messages

```elixir
socket
|> put_flash(:info, gettext("Product successfully created"))
|> push_navigate(to: ~p"/products")
```

### Example 3: Form Validation

```elixir
def changeset(product, attrs) do
  product
  |> cast(attrs, [:name, :price])
  |> validate_required([:name, :price], 
       message: gettext("can't be blank"))
  |> validate_number(:price, 
       greater_than: 0, 
       message: gettext("must be greater than 0"))
end
```

## Testing Translations

### Test different locales in IEx:

```elixir
# Start IEx
iex -S mix

# Test Indonesian (default)
Gettext.put_locale(VoileWeb.Gettext, "id")
VoileWeb.Gettext.gettext("Save")
# Returns: "Simpan"

# Test English
Gettext.put_locale(VoileWeb.Gettext, "en")
VoileWeb.Gettext.gettext("Save")
# Returns: "Save"
```

### Test in browser:

1. Visit any page: `http://localhost:4000`
2. Switch to English: `http://localhost:4000?locale=en`
3. Switch back to Indonesian: `http://localhost:4000?locale=id`

## Troubleshooting

### Translations not showing up?

1. Make sure you've compiled translations: `mix gettext.compile`
2. Restart your server
3. Check the `.po` files for correct `msgstr` values

### Wrong locale being used?

1. Check your session in browser dev tools
2. Clear browser cookies
3. Try with `?locale=id` or `?locale=en` in URL

### Missing translations showing as English?

This is expected - if a translation is missing, Gettext falls back to the `msgid` (which is usually in English).

Add the missing translation to the appropriate `.po` file.

## Resources

- [Phoenix Gettext Documentation](https://hexdocs.pm/gettext/Gettext.html)
- [Phoenix Internationalization Guide](https://hexdocs.pm/phoenix/Phoenix.html#module-internationalization-i18n)
- [GNU gettext format specification](https://www.gnu.org/software/gettext/manual/gettext.html)
