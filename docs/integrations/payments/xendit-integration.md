# Xendit Payment Gateway Integration for Library Fines

This document describes the Xendit payment gateway integration for handling library fine payments in the Voile system.

## Overview

The integration uses **Xendit Payment Links API** to enable online fine payments for library members. This approach simplifies PCI compliance and reduces development complexity by using Xendit's hosted payment pages.

## Features

### For Librarians (Dashboard)
- Generate payment links for member fines
- View payment status and transaction history
- Copy payment links to share with members
- Process both online and in-person (cash) payments
- Track payment attempts and failures

### For Members (Atrium)
- Request payment links for outstanding fines
- Pay fines online via Xendit's secure checkout
- View payment status and history
- Receive payment confirmations
- Pay in person at circulation desk as alternative

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Member/   │────▶│    Voile     │────▶│   Xendit    │
│  Librarian  │     │  Application │     │     API     │
└─────────────┘     └──────────────┘     └─────────────┘
                           │                     │
                           │   Webhook           │
                           │◀────────────────────┘
                           ▼
                    ┌──────────────┐
                    │   Database   │
                    │  (Payments)  │
                    └──────────────┘
```

### Components

1. **Client.Xendit** (`lib/client/xendit.ex`)
   - Xendit API client using Req library
   - Handles payment link creation and retrieval
   - Validates webhook signatures

2. **Voile.Schema.Library.Payment** (`lib/voile/schema/library/payment.ex`)
   - Payment record schema
   - Tracks payment gateway transactions
   - Links payments to fines

3. **Voile.Schema.Library.Circulation** (`lib/voile/schema/library/circulation.ex`)
   - Payment business logic
   - Creates payment links
   - Updates fine status from payments

4. **VoileWeb.XenditWebhookController** (`lib/voile_web/controllers/xendit_webhook_controller.ex`)
   - Receives Xendit callbacks
   - Validates webhook signatures
   - Updates payment and fine status

## Setup Instructions

### 1. Get Xendit API Credentials

1. Sign up for a Xendit account at https://dashboard.xendit.co/register
2. Navigate to **Settings → Developers → API Keys**
3. Copy your **Secret API Key** (starts with `xnd_...`)
4. Generate a **Webhook Verification Token** in Settings → Webhooks

### 2. Configure Environment Variables

Add the following to your `.env` file or environment:

```bash
# Xendit API Configuration
XENDIT_API_KEY=xnd_development_your_secret_key_here
XENDIT_WEBHOOK_TOKEN=your_webhook_verification_token_here
```

For production, use your production API keys:

```bash
XENDIT_API_KEY=xnd_production_your_production_key_here
XENDIT_WEBHOOK_TOKEN=your_production_webhook_token_here
```

### 3. Configure Webhook URL in Xendit Dashboard

1. Go to **Settings → Webhooks** in Xendit Dashboard
2. Add a new webhook with URL: `https://yourdomain.com/webhooks/xendit/payment`
3. Select event type: **Payment Link**
4. Use the same verification token from step 1

### 4. Update Application Configuration

The configuration is already set in `config/config.exs`:

```elixir
config :voile,
  xendit_api_key: System.get_env("XENDIT_API_KEY"),
  xendit_webhook_token: System.get_env("XENDIT_WEBHOOK_TOKEN")
```

### 5. Run Database Migration

The payment table migration has been created. Ensure it's applied:

```bash
mix ecto.migrate
```

### 6. Verify Installation

Start your application and check:

```bash
# Start the application
mix phx.server

# In another terminal, verify the webhook endpoint
curl -X POST http://localhost:4000/webhooks/xendit/payment \
  -H "Content-Type: application/json" \
  -H "X-Callback-Token: your_webhook_token" \
  -d '{"status": "PENDING"}'
```

## Usage

### For Librarians

#### Generate Payment Link in Ledger Page

1. Navigate to **Manage → GLAM → Library → Ledger**
2. Select a member: **Transact → [member]**
3. Go to **Fines** tab
4. Click **Pay** button next to a fine
5. In the modal:
   - If no payment link exists: Click **Generate Payment Link**
   - Share the link with the member (via email, WhatsApp, etc.)
   - Or process cash payment directly

#### View Payment Status

- Payment status is displayed in the fine modal
- Green badge = Paid
- Blue badge = Pending
- Red badge = Failed/Expired

### For Members

#### Request and Pay Fine Online

1. Login to member portal at `/atrium`
2. View **Outstanding Fines** section
3. Click **Get Payment Link** for any unpaid fine
4. Click **Pay Online** to open Xendit checkout
5. Complete payment using:
   - Credit/Debit Card
   - Bank Transfer (Virtual Account)
   - E-wallet (OVO, Dana, GoPay, LinkAja)
   - Retail Outlets (Alfamart, Indomaret)

#### After Payment

- Members are redirected back to atrium with success/failure message
- Webhook updates fine status automatically
- Members can view updated fine status immediately

## Payment Flow

### Standard Payment Flow

```
1. Member has overdue fine
   ↓
2. Librarian/Member generates payment link
   ↓
3. Payment record created (status: pending)
   ↓
4. Xendit creates checkout page
   ↓
5. Member completes payment on Xendit
   ↓
6. Xendit sends webhook to Voile
   ↓
7. Webhook handler updates payment (status: paid)
   ↓
8. Fine status updated (status: paid)
   ↓
9. Member notified of successful payment
```

### Webhook Events

The system handles these Xendit payment link statuses:

- **PENDING** - Payment link created, awaiting payment
- **PAID** - Payment successful
- **EXPIRED** - Payment link expired (default: 24 hours)
- **FAILED** - Payment failed

## Database Schema

### lib_payments table

```sql
CREATE TABLE lib_payments (
  id                UUID PRIMARY KEY,
  fine_id          UUID REFERENCES lib_fines,
  member_id        UUID REFERENCES users NOT NULL,
  payment_gateway  VARCHAR DEFAULT 'xendit',
  payment_link_id  VARCHAR,
  external_id      VARCHAR NOT NULL UNIQUE,
  payment_url      VARCHAR,
  amount           DECIMAL(15,2) NOT NULL,
  paid_amount      DECIMAL(15,2) DEFAULT 0,
  currency         VARCHAR DEFAULT 'IDR',
  payment_method   VARCHAR,
  payment_channel  VARCHAR,
  status           VARCHAR DEFAULT 'pending',
  payment_date     TIMESTAMP,
  expired_at       TIMESTAMP,
  failure_reason   VARCHAR,
  description      TEXT,
  callback_data    JSONB,
  metadata         JSONB,
  processed_by_id  UUID REFERENCES users,
  inserted_at      TIMESTAMP NOT NULL,
  updated_at       TIMESTAMP NOT NULL
);

-- Indexes
CREATE INDEX idx_payments_fine_id ON lib_payments(fine_id);
CREATE INDEX idx_payments_member_id ON lib_payments(member_id);
CREATE INDEX idx_payments_external_id ON lib_payments(external_id);
CREATE INDEX idx_payments_status ON lib_payments(status);
```

## API Reference

### Circulation Context Functions

#### Create Payment Link

```elixir
Circulation.create_payment_link_for_fine(fine_id, processed_by_id, opts \\ [])

# Options:
# - success_redirect_url: URL after successful payment
# - failure_redirect_url: URL after failed payment

# Returns: {:ok, %Payment{}} | {:error, reason}
```

#### Get Payment by External ID

```elixir
Circulation.get_payment_by_external_id(external_id)

# Returns: {:ok, %Payment{}} | {:error, :not_found}
```

#### Handle Webhook

```elixir
Circulation.handle_payment_webhook(webhook_payload)

# Returns: {:ok, %Payment{}} | {:error, reason}
```

#### List Fine Payments

```elixir
Circulation.list_fine_payments(fine_id)

# Returns: [%Payment{}]
```

## Testing

### Test Payment Link Creation

```elixir
# In IEx console
iex> fine = Voile.Schema.Library.Circulation.get_fine!("fine-uuid")
iex> {:ok, payment} = Voile.Schema.Library.Circulation.create_payment_link_for_fine(
  fine.id, 
  "librarian-uuid",
  success_redirect_url: "https://yourapp.com/atrium?payment=success",
  failure_redirect_url: "https://yourapp.com/atrium?payment=failed"
)
iex> IO.inspect(payment.payment_url)
```

### Test Webhook (Development)

Use Xendit's test mode to simulate payments:

1. Use test API key (starts with `xnd_development_`)
2. Create payment link
3. Use Xendit's test card numbers:
   - Success: `4000000000001091`
   - Failure: `4000000000000002`
4. Check webhook logs in Xendit Dashboard

### Simulate Webhook Locally

```bash
curl -X POST http://localhost:4000/webhooks/xendit/payment \
  -H "Content-Type: application/json" \
  -H "X-Callback-Token: your_webhook_token" \
  -d '{
    "id": "pl-xxx",
    "external_id": "fine_123_1234567890",
    "status": "PAID",
    "paid_amount": 50000,
    "payment_method": "CREDIT_CARD",
    "paid_at": "2024-10-24T10:00:00.000Z"
  }'
```

## Troubleshooting

### Payment Link Not Generated

**Problem**: Error "API key not configured"

**Solution**: Ensure `XENDIT_API_KEY` environment variable is set

```bash
# Check if variable is set
echo $XENDIT_API_KEY

# Set temporarily
export XENDIT_API_KEY=xnd_development_your_key

# Or add to .env file
```

### Webhook Not Received

**Problem**: Payments complete but status not updated

**Solution**:
1. Check webhook URL is correct in Xendit Dashboard
2. Verify webhook verification token matches
3. Check application logs for webhook errors
4. Test webhook manually with curl

### Payment Link Expired

**Problem**: Payment links expire too quickly

**Solution**: Xendit payment links expire after 24 hours by default. Generate a new link if expired.

### Fine Not Marked as Paid

**Problem**: Payment successful but fine still unpaid

**Solution**:
1. Check `lib_payments` table for payment record
2. Verify webhook was received (check `callback_data` column)
3. Manually mark payment as paid:

```elixir
# In IEx
payment = Voile.Repo.get_by(Voile.Schema.Library.Payment, external_id: "fine_xxx")
Voile.Schema.Library.Circulation.mark_payment_as_paid(payment.id, "librarian-id")
```

## Security Considerations

1. **API Key Protection**
   - Never commit API keys to version control
   - Use environment variables for all credentials
   - Rotate keys periodically

2. **Webhook Validation**
   - Always validate `X-Callback-Token` header
   - Log suspicious webhook attempts
   - Use HTTPS in production

3. **Payment Verification**
   - Webhook handler verifies payment belongs to correct member
   - Amount validation ensures no tampering
   - Idempotent webhook processing prevents duplicate credits

## Production Checklist

- [ ] Production Xendit API keys configured
- [ ] Webhook URL points to production domain
- [ ] HTTPS enabled for webhook endpoint
- [ ] Webhook verification token is strong and secret
- [ ] Success/failure redirect URLs are correct
- [ ] Email notifications configured (optional)
- [ ] Error monitoring/alerting setup
- [ ] Database backups enabled
- [ ] Test end-to-end payment flow

## Support and Resources

- **Xendit Documentation**: https://developers.xendit.co/
- **Xendit Dashboard**: https://dashboard.xendit.co/
- **Payment Links API**: https://developers.xendit.co/api-reference/#payment-links
- **Webhook Guide**: https://developers.xendit.co/api-reference/#webhooks

## License

This integration is part of the Voile Library Management System.
