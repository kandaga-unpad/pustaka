# Email Queue System Guide

## Overview

The email queue system prevents your emails from being flagged as spam by spacing out email sends with configurable delays. Instead of sending all reminder emails at once, emails are queued and sent one at a time with a delay between each send.

## Features

✅ **Rate Limiting**: Configurable delay between emails (default: 2 seconds)
✅ **Retry Logic**: Failed emails are automatically retried up to N times
✅ **Priority Queue**: Support for urgent emails (e.g., overdue notifications)
✅ **Statistics**: Track sent, failed, and queued emails
✅ **Graceful Degradation**: Queue persists if a send fails

## How It Works

```
Scheduler Runs → Emails Queued → Queue Processes → Emails Sent
                                    (with delays)    (one by one)
```

1. **Scheduler identifies members** who need reminders
2. **Emails are queued** instead of sent immediately
3. **Queue processes emails** one at a time with configured delay
4. **Failed emails retry** automatically (up to max retries)
5. **Stats are tracked** for monitoring

## Configuration

All settings can be configured via environment variables in `.env`:

### Email Queue Delay

```bash
export VOILE_EMAIL_QUEUE_DELAY=2000  # milliseconds between emails
```

**Recommended values:**

| Delay | Emails/Min | Emails/Hour | Use Case |
|-------|------------|-------------|----------|
| 1000ms (1s) | 60 | 3,600 | Fast but riskier |
| 2000ms (2s) | 30 | 1,800 | **RECOMMENDED** |
| 3000ms (3s) | 20 | 1,200 | Conservative |
| 5000ms (5s) | 12 | 720 | Very safe |

**Default: 2000ms (2 seconds)** - Good balance for Google Workspace

### Maximum Retries

```bash
export VOILE_EMAIL_QUEUE_MAX_RETRIES=3  # retry attempts
```

**Default: 3 retries** - Emails will be attempted 4 times total (1 initial + 3 retries)

## Calculating Your Needs

### Example: 500 Active Borrowers

If you have 500 active borrowers and run reminders daily:

- **3 days before**: ~50-100 emails (10-20% due in 3 days)
- **1 day before**: ~50-100 emails (10-20% due in 1 day)
- **Overdue**: ~20-50 emails (4-10% overdue)
- **Total**: ~120-250 emails/day

**Time to send with different delays:**

- **1 second delay**: 120-250 seconds = **2-4 minutes**
- **2 second delay**: 240-500 seconds = **4-8 minutes** ✅ RECOMMENDED
- **3 second delay**: 360-750 seconds = **6-12 minutes**
- **5 second delay**: 600-1250 seconds = **10-20 minutes**

### Google Workspace Limits

- **Sending limit**: 2,000 messages/day per user
- **Rate limit**: 86 messages/minute burst (soft limit)

With **2 second delay (30 emails/min)**, you're well under the burst limit and can send 1,800 emails/hour.

## Monitoring Queue

### Check Queue Status in IEx Console

```elixir
# Get current statistics
Voile.Notifications.EmailQueue.stats()

# Returns:
# %{
#   sent: 150,
#   failed: 2,
#   retried: 5,
#   queued: 0,
#   queue_size: 10  # emails still in queue
# }
```

### Pause/Resume Queue

```elixir
# Pause email sending (useful during maintenance)
Voile.Notifications.EmailQueue.pause()

# Resume email sending
Voile.Notifications.EmailQueue.resume()
```

### Clear Queue

```elixir
# Clear all queued emails (use with caution!)
Voile.Notifications.EmailQueue.clear_queue()
```

## Priority Emails

Different email types have different priorities:

- **High Priority**: Overdue notifications (sent first)
- **Normal Priority**: Regular reminders (3 days, 1 day before)
- **Normal Priority**: Manual reminders from librarians

Higher priority emails are processed before lower priority ones.

## Logs

The queue logs all activity. Check your application logs:

```bash
# View logs
tail -f /var/log/voile/error.log

# Example log output:
[info] Email queue started with delay: 2000ms
[info] Email queued: email_12345 (priority: normal, queue size: 15)
[info] Processing email job: email_12345 (attempt 1/4)
[info] Email sent successfully: email_12345
```

## Troubleshooting

### Emails Not Sending

1. **Check if queue is paused:**
   ```elixir
   Voile.Notifications.EmailQueue.stats()
   # If queue_size keeps growing but sent doesn't increase
   Voile.Notifications.EmailQueue.resume()
   ```

2. **Check SMTP configuration:**
   ```bash
   # Verify env vars are set
   echo $VOILE_SMTP_RELAY
   echo $VOILE_SMTP_USERNAME
   ```

3. **Check application logs:**
   ```bash
   tail -f /var/log/voile/error.log | grep -i email
   ```

### Too Many Failed Emails

If `failed` count is high in stats:

1. **Check SMTP credentials** are correct
2. **Verify network connectivity** to SMTP server
3. **Check if being rate limited** by email provider
4. **Increase delay** between emails

### Queue Growing Too Large

If `queue_size` keeps growing:

1. **Check if EmailQueue process is running:**
   ```elixir
   Process.whereis(Voile.Notifications.EmailQueue)
   # Should return a PID
   ```

2. **Check if processing is stuck:**
   ```bash
   # Look for errors in logs
   grep "Email job crashed" /var/log/voile/error.log
   ```

3. **Restart the application** if queue is stuck

## Performance Tips

### For Large Institutions (1000+ borrowers)

1. **Use faster delay** during off-peak hours:
   ```bash
   export VOILE_EMAIL_QUEUE_DELAY=1000  # 1 second
   ```

2. **Schedule reminders at night**:
   ```bash
   # Run at 2 AM when email traffic is low
   export VOILE_LOAN_REMINDER_INTERVAL=86400000
   ```

3. **Monitor queue size** regularly to ensure it processes fast enough

### For Small Institutions (< 200 borrowers)

1. **Use conservative delay** to stay safe:
   ```bash
   export VOILE_EMAIL_QUEUE_DELAY=3000  # 3 seconds
   ```

2. **No need to worry** about queue size - will process in 5-10 minutes

## Integration with Scheduler

The scheduler automatically uses the queue:

```elixir
# When scheduler runs, emails are queued, not sent immediately
def send_member_reminder(member_id, transactions, days_before_due) do
  # Email is queued here
  EmailQueue.enqueue(
    fn -> LoanReminderEmail.send_reminder_email(member, transactions, days_before_due) end,
    metadata: %{member_id: member_id, type: :reminder}
  )
  
  # PubSub notifications are sent immediately (no queue)
  LoanReminderNotifier.broadcast_loan_reminder(transaction, days_before_due)
end
```

**Key Points:**
- ✅ Emails are queued (rate-limited)
- ✅ PubSub notifications are immediate (no delay)
- ✅ Queue processes automatically in background

## Best Practices

1. **Start Conservative**: Use 2-3 second delay initially
2. **Monitor Stats**: Check `EmailQueue.stats()` daily for first week
3. **Adjust as Needed**: Increase speed if queue grows too large
4. **Test in Production**: Send manual reminder to yourself first
5. **Schedule Off-Peak**: Run scheduler during low-traffic hours
6. **Watch Gmail**: Check if emails land in inbox vs spam

## Email Provider Recommendations

### Google Workspace (Recommended)

- **Sending limit**: 2,000/day per account
- **Recommended delay**: 2000ms (2 seconds)
- **Safe rate**: 30 emails/minute
- **Cost**: Varies by plan

### Mailgun

- **Sending limit**: 100/hour (free tier)
- **Recommended delay**: 5000ms (5 seconds)
- **Safe rate**: 12 emails/minute
- **Cost**: Free tier available

### SendGrid

- **Sending limit**: 100/day (free tier)
- **Recommended delay**: 3000ms (3 seconds)
- **Safe rate**: 20 emails/minute
- **Cost**: Free tier available

## Summary

✅ **Default settings (2 second delay, 3 retries) work for most institutions**
✅ **Queue prevents spam flagging by spacing out sends**
✅ **Failed emails retry automatically**
✅ **Monitor with `EmailQueue.stats()` in IEx console**
✅ **Adjust delay based on your institution size and email volume**

For most libraries with 200-500 active borrowers, the default 2 second delay is perfect! 🎉
