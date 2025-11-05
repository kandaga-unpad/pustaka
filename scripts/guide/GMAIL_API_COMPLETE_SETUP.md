# Gmail API Complete Setup Guide

## ✅ What Was Done

The Gmail API OAuth2 implementation has been completed with the following changes:

### 1. Created Custom Gmail API Adapter
- **File**: `lib/voile/mailer/gmail_api_adapter.ex`
- Custom Swoosh adapter for Gmail API (since Swoosh doesn't have built-in support)
- Auto-refresh token mechanism
- Proper error handling and logging

### 2. OAuth2 Helper Module
- **File**: `lib/voile/mailer/gmail_auth.ex`
- Interactive setup wizard: `Voile.Mailer.GmailAuth.interactive_setup()`
- Token refresh functionality
- Authorization URL generation

### 3. Gmail Callback Controller & Route
- **File**: `lib/voile_web/controllers/gmail_callback_controller.ex`
- Handles OAuth2 callback from Google
- Beautiful success/error pages
- **Route**: `GET /auth/gmail/callback` (separate from user login OAuth)

### 4. Router Configuration
- **File**: `lib/voile_web/router.ex`
- Added dedicated Gmail API callback route
- Separated from Google user authentication (`/auth/google/callback`)

### 5. Runtime Configuration
- **File**: `config/runtime.exs`
- Gmail API adapter configuration
- Environment variable mapping with VOILE_ prefix

### 6. Documentation
- **GMAIL_API_SETUP.md**: Comprehensive setup guide
- **GMAIL_API_QUICKSTART.md**: Quick reference
- **.env.example**: Updated with Gmail API configuration

## 🔧 Key Design Decisions

### Separate Callback URLs
Your application has TWO different OAuth flows:

1. **User Login** (existing): `GET /auth/google/callback`
   - Used by Assent for Google user authentication
   - Handles user login via Google
   
2. **Gmail API Setup** (new): `GET /auth/gmail/callback`
   - Used only during initial setup to get Gmail API tokens
   - One-time process to obtain access/refresh tokens

**Why separate?** They serve different purposes and have different state management requirements. Mixing them causes the `BadMapError` you saw.

## 📝 How to Complete Setup

### Step 1: Update Google Cloud Console

1. Go to https://console.cloud.google.com/
2. Select your project
3. Navigate to **APIs & Services** → **Credentials**
4. Click on your OAuth 2.0 Client ID
5. Under **Authorized redirect URIs**, ADD (don't replace):
   ```
   http://localhost:4000/auth/gmail/callback
   ```
   
   **Important**: Keep your existing `/auth/google/callback` URI for user login!
   
6. Click **Save**

### Step 2: Update Your .env File

Add these variables to your `.env`:

```bash
# Gmail API Configuration
export VOILE_MAILER_ADAPTER=gmail_api
export VOILE_GMAIL_CLIENT_ID=your-client-id.apps.googleusercontent.com
export VOILE_GMAIL_CLIENT_SECRET=your-client-secret
export VOILE_GMAIL_REDIRECT_URI=http://localhost:4000/auth/gmail/callback

# These will be filled after interactive setup:
# export VOILE_GMAIL_ACCESS_TOKEN=ya29...
# export VOILE_GMAIL_REFRESH_TOKEN=1//0g...
```

### Step 3: Load Environment Variables

```bash
source .env
```

### Step 4: Run Interactive Setup

```bash
# Start IEx
iex -S mix

# In the IEx console, run:
Voile.Mailer.GmailAuth.interactive_setup()
```

### Step 5: Follow the Wizard

1. Copy the URL displayed in the terminal
2. Open it in your browser
3. Authorize the application
4. You'll be redirected to a success page showing your authorization code
5. The tokens will be displayed in your terminal
6. Copy the access_token and refresh_token

### Step 6: Add Tokens to .env

```bash
export VOILE_GMAIL_ACCESS_TOKEN="ya29.a0AfB_byD..."
export VOILE_GMAIL_REFRESH_TOKEN="1//0gL..."
```

### Step 7: Reload Environment

```bash
source .env
```

### Step 8: Test Email Sending

```elixir
# In IEx:
Voile.Mailer.deliver(
  Swoosh.Email.new(
    to: "your-email@example.com",
    from: {"Library System", "library@youruniversity.edu"},
    subject: "Test Email via Gmail API",
    text_body: "If you receive this, Gmail API is working!"
  )
)
```

## 🚀 Production Deployment

### Update Google Cloud Console for Production

1. Add production redirect URI:
   ```
   https://yourdomain.com/auth/gmail/callback
   ```

### Set Production Environment Variables

```bash
export VOILE_MAILER_ADAPTER=gmail_api
export VOILE_GMAIL_CLIENT_ID=your-production-client-id
export VOILE_GMAIL_CLIENT_SECRET=your-production-client-secret
export VOILE_GMAIL_REDIRECT_URI=https://yourdomain.com/auth/gmail/callback
export VOILE_GMAIL_ACCESS_TOKEN=ya29...
export VOILE_GMAIL_REFRESH_TOKEN=1//0g...
```

### Kubernetes Secrets (if using k8s)

Update `k8s/secrets.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: voile-secrets
type: Opaque
stringData:
  VOILE_MAILER_ADAPTER: gmail_api
  VOILE_GMAIL_CLIENT_ID: your-client-id
  VOILE_GMAIL_CLIENT_SECRET: your-client-secret
  VOILE_GMAIL_REDIRECT_URI: https://yourdomain.com/auth/gmail/callback
  VOILE_GMAIL_ACCESS_TOKEN: ya29...
  VOILE_GMAIL_REFRESH_TOKEN: 1//0g...
```

## 🔍 Troubleshooting

### "No route found for GET /auth/gmail/callback"

**Solution**: This was fixed! Make sure you have the latest code:
- Controller: `lib/voile_web/controllers/gmail_callback_controller.ex`
- Route added in: `lib/voile_web/router.ex`

### "BadMapError" or state verification failure

**Cause**: You're using the wrong callback URL (`/auth/google/callback` instead of `/auth/gmail/callback`)

**Solution**:
1. Update Google Cloud Console with correct redirect URI
2. Update `.env` with `VOILE_GMAIL_REDIRECT_URI=http://localhost:4000/auth/gmail/callback`
3. Reload environment and try again

### "invalid_grant" or "Malformed auth code"

**Causes**:
- Authorization code expired (valid for ~10 minutes)
- Code was already used (can only use once)
- Wrong redirect URI in Google Cloud Console

**Solution**: Start over from Step 1 of interactive setup

### Tokens not refreshing

**Check**:
1. `VOILE_GMAIL_REFRESH_TOKEN` is set correctly
2. Logs show: `[info] Gmail API: Refreshing access token`
3. If still failing, run interactive setup again (you may need new tokens)

## 📊 How It Works

### Token Lifecycle

1. **Initial Setup** (one-time):
   - Run `interactive_setup()`
   - Get authorization code from Google
   - Exchange code for access_token + refresh_token
   - Store both in environment

2. **Sending Emails**:
   - Adapter uses access_token to send via Gmail API
   - Access tokens expire after ~1 hour

3. **Auto-Refresh**:
   - When access_token expires, adapter automatically:
     - Uses refresh_token to get new access_token
     - Updates the token in memory
     - Continues sending emails seamlessly

### Why This Is Better Than SMTP

- ✅ **No App Passwords**: Google is deprecating these
- ✅ **More Secure**: OAuth2 with scoped permissions
- ✅ **Auto-Refresh**: Tokens refresh automatically
- ✅ **Better Limits**: 2,000 emails/day (vs 500 with SMTP)
- ✅ **Modern API**: RESTful, well-documented
- ✅ **Reliable**: Direct API access, fewer failures

## 🎯 Summary

You now have:
- ✅ Gmail API OAuth2 fully implemented
- ✅ Separate callback URLs for user login vs email setup
- ✅ Custom Swoosh adapter with auto-refresh
- ✅ Interactive setup wizard
- ✅ Beautiful success/error pages
- ✅ All environment variables using VOILE_ prefix
- ✅ Complete documentation

**Next Steps**: Follow "How to Complete Setup" above to get your tokens!
