# Quick Start: Xendit Payment Integration

## 1. Get Xendit Credentials

Sign up at https://dashboard.xendit.co and get:
- Secret API Key from Settings → Developers → API Keys
- Webhook Verification Token from Settings → Webhooks

## 2. Set Environment Variables

```bash
# Add to .env or export
export XENDIT_API_KEY=xnd_development_your_key_here
export XENDIT_WEBHOOK_TOKEN=your_webhook_token_here
```

## 3. Configure Webhook in Xendit

1. Go to Xendit Dashboard → Settings → Webhooks
2. Add webhook URL: `https://yourdomain.com/webhooks/xendit/payment`
3. Select event: **Payment Link**
4. Set verification token (same as above)

## 4. Test Integration

### Test Payment Link Creation (Librarian)

1. Go to `/manage/glam/library/ledger`
2. Select a member with fines
3. Click "Fines" tab → "Pay" button
4. Click "Generate Payment Link"
5. Copy and test the payment URL

### Test Member Payment Flow

1. Login as member at `/atrium`
2. View "Outstanding Fines"
3. Click "Get Payment Link"
4. Click "Pay Online"
5. Use Xendit test cards:
   - Success: `4000000000001091`
   - Failure: `4000000000000002`

## 5. Verify Webhook

Check your application logs for webhook events:

```bash
# Watch logs
tail -f log/dev.log | grep -i xendit

# Or check database
psql -d voile_dev -c "SELECT * FROM lib_payments ORDER BY inserted_at DESC LIMIT 5;"
```

## Done! 🎉

Your payment integration is ready. See `XENDIT_PAYMENT_INTEGRATION.md` for full documentation.

## Quick Reference

### For Librarians
- Generate payment links in Ledger → Fines tab
- Share links via WhatsApp/Email
- Process cash payments directly

### For Members  
- Request payment links in Atrium
- Pay online via Xendit checkout
- Multiple payment methods supported

### Payment Status
- 🔵 **Pending** - Awaiting payment
- 🟢 **Paid** - Successfully paid
- 🔴 **Failed/Expired** - Payment unsuccessful

## Need Help?

See full documentation: `XENDIT_PAYMENT_INTEGRATION.md`
