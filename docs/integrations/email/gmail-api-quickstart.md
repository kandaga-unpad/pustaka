# Gmail API Quick Start

## Prerequisites
- Google Cloud Console account
- Gmail account for sending emails

## 1. Google Cloud Setup (5 minutes)

```
1. Go to: https://console.cloud.google.com/apis
2. Enable "Gmail API"
3. Create OAuth 2.0 Client ID
4. Add redirect URI: http://localhost:4000/auth/gmail/callback
5. Copy Client ID and Client Secret
```

## 2. Environment Setup

Add to `.env`:
```bash
VOILE_GMAIL_CLIENT_ID="your-client-id.apps.googleusercontent.com"
VOILE_GMAIL_CLIENT_SECRET="your-client-secret"
VOILE_GMAIL_REDIRECT_URI="http://localhost:4000/auth/gmail/callback"
VOILE_MAILER_ADAPTER="gmail_api"
```

## 3. Get Tokens (One-Time)

```bash
iex -S mix
```

```elixir
Voile.Mailer.GmailAuth.interactive_setup()
```

Follow the prompts and add the tokens to `.env`:
```bash
VOILE_GMAIL_ACCESS_TOKEN="ya29...."
VOILE_GMAIL_REFRESH_TOKEN="1//0g..."
```

## 4. Test

Restart IEx and test:
```elixir
import Swoosh.Email

new()
|> to("test@example.com")
|> from({"Your Name", "your-gmail@gmail.com"})
|> subject("Test")
|> text_body("It works!")
|> Voile.Mailer.deliver()
```

## That's It!

The adapter will automatically refresh tokens when needed.

See `GMAIL_API_SETUP.md` for detailed guide and troubleshooting.
