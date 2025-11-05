# Gmail API Setup Guide

This guide walks you through setting up Gmail API authentication for sending emails from your Voile application.

## Why Gmail API Instead of SMTP?

- **More Secure**: Uses OAuth2 instead of storing passwords
- **No App Passwords Needed**: Google is deprecating app passwords
- **Better Rate Limits**: Gmail API has higher limits than SMTP
- **Official Support**: Google recommends API over SMTP for applications

## Step-by-Step Setup

### 1. Configure Google Cloud Console

1. Go to https://console.cloud.google.com/
2. Create a new project or select existing one
3. Enable the **Gmail API**:
   - Go to "APIs & Services" → "Library"
   - Search for "Gmail API"
   - Click "Enable"

### 2. Configure OAuth Consent Screen

1. Go to "APIs & Services" → "OAuth consent screen"
2. Choose **External** (unless you have Google Workspace)
3. Fill in required fields:
   - App name: `Voile` (or your app name)
   - User support email: Your email
   - Developer contact: Your email
4. Add scopes:
   - Click "Add or Remove Scopes"
   - Filter for "gmail"
   - Select: `https://www.googleapis.com/auth/gmail.send`
5. Add test users (for testing):
   - Add the Gmail account you'll use to send emails
6. Save and continue

### 3. Create OAuth 2.0 Credentials

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth 2.0 Client ID"
3. Choose **Web application**
4. Set name: `Voile Gmail Client`
5. Add Authorized redirect URIs:
   - Development: `http://localhost:4000/auth/gmail/callback`
   - Production: `https://yourdomain.com/auth/gmail/callback`
6. Click "Create"
7. **Save the Client ID and Client Secret** - you'll need these!

### 4. Set Environment Variables

Create or update your `.env` file:

```bash
# Gmail API OAuth2 Credentials
VOILE_GMAIL_CLIENT_ID="your-client-id.apps.googleusercontent.com"
VOILE_GMAIL_CLIENT_SECRET="your-client-secret"
VOILE_GMAIL_REDIRECT_URI="http://localhost:4000/auth/gmail/callback"

# These will be generated in next step
VOILE_GMAIL_ACCESS_TOKEN=""
VOILE_GMAIL_REFRESH_TOKEN=""

# Set mailer adapter to use Gmail API
VOILE_MAILER_ADAPTER="gmail_api"
```

### 5. Get OAuth Tokens (One-Time Setup)

Start your Phoenix server or IEx:

```bash
iex -S mix
```

Run the interactive setup:

```elixir
Voile.Mailer.GmailAuth.interactive_setup()
```

This will:
1. Generate an authorization URL
2. Open it in your browser
3. Ask you to authorize the app
4. Provide you with access and refresh tokens

Copy the tokens and add them to your `.env`:

```bash
VOILE_GMAIL_ACCESS_TOKEN="ya29.a0AfB_byD..."
VOILE_GMAIL_REFRESH_TOKEN="1//0gL..."
```

**Important**: The refresh token is generated only once! Save it securely.

### 6. Test Email Sending

In IEx:

```elixir
# Restart to load new environment variables
System.halt(0)
```

Start again and test:

```bash
iex -S mix
```

```elixir
import Swoosh.Email

email =
  new()
  |> to("recipient@example.com")
  |> from({"Voile", "your-gmail@gmail.com"})
  |> subject("Test Email via Gmail API")
  |> text_body("This email was sent using Gmail API!")
  |> html_body("<p>This email was sent using <strong>Gmail API</strong>!</p>")

Voile.Mailer.deliver(email)
```

If successful, you should see:
```elixir
{:ok, %{id: "message_id"}}
```

## Production Deployment

### Environment Variables

Set these in your production environment:

```bash
export VOILE_MAILER_ADAPTER="gmail_api"
export VOILE_GMAIL_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export VOILE_GMAIL_CLIENT_SECRET="your-client-secret"
export VOILE_GMAIL_ACCESS_TOKEN="ya29.a0AfB_byD..."
export VOILE_GMAIL_REFRESH_TOKEN="1//0gL..."
export VOILE_GMAIL_REDIRECT_URI="https://yourdomain.com/auth/gmail/callback"
```

### Token Refresh

The adapter automatically refreshes the access token when it expires using the refresh token. No manual intervention needed!

### Monitoring

Check your logs for:
- `Gmail access token refreshed successfully` - Token was auto-refreshed
- `Email sent successfully via Gmail API` - Email sent
- Any errors will be logged with details

## Troubleshooting

### "Access blocked: This app's request is invalid"

**Solution**: Make sure you've added the Gmail account as a test user in OAuth consent screen.

### "invalid_grant" error

**Solution**: The authorization code expired. Run `interactive_setup()` again.

### "insufficient_permissions" error

**Solution**: Make sure you added the `gmail.send` scope in OAuth consent screen.

### Token expired and refresh failed

**Solution**: Run `interactive_setup()` again to get new tokens.

### "redirect_uri_mismatch" error

**Solution**: Make sure the redirect URI in your .env matches exactly what's configured in Google Cloud Console.

## Security Best Practices

1. **Never commit tokens to git**: Use `.env` files and add them to `.gitignore`
2. **Use environment variables**: Never hardcode credentials
3. **Rotate tokens periodically**: Re-run setup every few months
4. **Limit scopes**: Only use `gmail.send` scope, not full Gmail access
5. **Use secrets management**: In production, use proper secrets management (e.g., AWS Secrets Manager, HashiCorp Vault)

## Alternative: Service Account (Google Workspace Only)

If you have Google Workspace, you can use a service account instead:

1. Create a service account in Google Cloud Console
2. Enable domain-wide delegation
3. Configure in Workspace Admin Console
4. Use a different adapter implementation

This guide focuses on OAuth2 for regular Gmail accounts.

## API Limits

- **Free Gmail**: 500 emails/day
- **Google Workspace**: 2,000 emails/day (or more with quota increase)

Monitor your usage in Google Cloud Console → "APIs & Services" → "Dashboard"

## Support

If you encounter issues:
1. Check Google Cloud Console logs
2. Check your application logs
3. Verify all scopes are correctly configured
4. Ensure test users are added (for development)
