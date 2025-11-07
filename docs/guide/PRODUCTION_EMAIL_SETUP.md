# Production Email Setup Guide

This guide covers setting up email delivery for the Voile library system in production.

## Table of Contents
1. [Option 1: Google Workspace (Recommended)](#option-1-google-workspace-recommended)
2. [Option 2: Self-Hosted SMTP](#option-2-self-hosted-smtp)
3. [Environment Variables](#environment-variables)
4. [Testing Email](#testing-email)
5. [Monitoring & Troubleshooting](#monitoring--troubleshooting)

---

## Option 1: Google Workspace (Recommended)

### Why Google Workspace?

✅ **Best for your use case:**
- **20,000 emails/day per user** (plenty for 5k-20k/month)
- Already paid for through university subscription
- High deliverability (Gmail's excellent reputation)
- No maintenance or server setup needed
- Built-in spam filtering and security
- DKIM, SPF, DMARC already configured

### Setup Steps

#### 1. Create Dedicated Email Account
```bash
# Create a service account in Google Workspace Admin
# Example: library-system@youruniversity.edu
# or: noreply@youruniversity.edu
```

#### 2. Enable 2-Factor Authentication
1. Go to https://myaccount.google.com
2. Security → 2-Step Verification
3. Enable 2FA for the account

#### 3. Generate App Password
1. Go to https://myaccount.google.com/apppasswords
2. Select "Mail" and "Other (Custom name)"
3. Name it "Voile Library System"
4. Copy the 16-character password (e.g., `abcd efgh ijkl mnop`)

#### 4. Configure Environment Variables

Add to your `.env` or server environment:

```bash
# Mailer Configuration
MAILER_ADAPTER=smtp

# Google Workspace SMTP Settings
SMTP_RELAY=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=library-system@youruniversity.edu
SMTP_PASSWORD=abcdefghijklmnop  # App password (remove spaces)
SMTP_SSL=false  # Port 587 uses STARTTLS, not SSL
```

#### 5. Update Email "From" Address

Edit `/lib/voile/notifications/loan_reminder_email.ex`:

```elixir
# Change from:
|> from({"Library System", "noreply@library.system"})

# To:
|> from({"University Library", "library-system@youruniversity.edu"})
```

### Google Workspace Limits

| Metric | Limit | Your Needs |
|--------|-------|------------|
| Emails/day | 20,000 | 5,000-20,000/month = ~166-666/day ✅ |
| Recipients/email | 500 | Individual emails ✅ |
| Attachments | 25 MB | No attachments ✅ |

**Verdict:** Google Workspace is MORE than sufficient for your needs!

---

## Option 2: Self-Hosted SMTP

Use this if you want full control or can't use Google Workspace.

### Prerequisites

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y postfix mailutils libsasl2-2 ca-certificates libsasl2-modules
```

### Install and Configure Postfix

#### 1. Install Postfix

```bash
sudo apt install postfix
```

During installation, select:
- **Internet Site**
- **System mail name:** yourdomain.edu

#### 2. Configure Postfix

Edit `/etc/postfix/main.cf`:

```bash
sudo nano /etc/postfix/main.cf
```

Add/modify these settings:

```conf
# Basic settings
myhostname = mail.yourdomain.edu
mydomain = yourdomain.edu
myorigin = $mydomain
inet_interfaces = all
inet_protocols = ipv4

# Relay settings
relayhost =
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

# Network settings
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128

# Mailbox settings
home_mailbox = Maildir/

# SMTP security
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_tls_security_level=may
smtp_tls_CApath=/etc/ssl/certs
smtp_tls_security_level=may
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache

# SMTP authentication
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination
```

#### 3. Install and Configure Dovecot (for SASL authentication)

```bash
sudo apt install dovecot-core dovecot-imapd
```

Edit `/etc/dovecot/conf.d/10-master.conf`:

```bash
sudo nano /etc/dovecot/conf.d/10-master.conf
```

Add SMTP authentication:

```conf
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}
```

#### 4. Restart Services

```bash
sudo systemctl restart postfix
sudo systemctl restart dovecot
sudo systemctl enable postfix
sudo systemctl enable dovecot
```

#### 5. Configure DNS Records

**CRITICAL:** Add these DNS records for deliverability:

**A Record:**
```
mail.yourdomain.edu.  IN  A  YOUR_SERVER_IP
```

**MX Record:**
```
yourdomain.edu.  IN  MX  10  mail.yourdomain.edu.
```

**SPF Record:**
```
yourdomain.edu.  IN  TXT  "v=spf1 mx ip4:YOUR_SERVER_IP ~all"
```

**DKIM Record** (generate with OpenDKIM):
```bash
sudo apt install opendkim opendkim-tools
sudo opendkim-genkey -t -s mail -d yourdomain.edu
```

**DMARC Record:**
```
_dmarc.yourdomain.edu.  IN  TXT  "v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.edu"
```

#### 6. Configure SSL Certificate (Let's Encrypt)

```bash
sudo apt install certbot

# Generate certificate
sudo certbot certonly --standalone -d mail.yourdomain.edu

# Update Postfix config
sudo nano /etc/postfix/main.cf
```

Update certificate paths:

```conf
smtpd_tls_cert_file=/etc/letsencrypt/live/mail.yourdomain.edu/fullchain.pem
smtpd_tls_key_file=/etc/letsencrypt/live/mail.yourdomain.edu/privkey.pem
```

#### 7. Environment Variables for Self-Hosted

```bash
MAILER_ADAPTER=smtp
SMTP_RELAY=localhost
SMTP_PORT=25
SMTP_USERNAME=voile
SMTP_PASSWORD=your_password
SMTP_SSL=false
```

### Self-Hosted Drawbacks

❌ **Challenges:**
- Complex DNS configuration (SPF, DKIM, DMARC)
- IP reputation takes time to build
- High risk of emails going to spam initially
- Requires constant monitoring
- Need to handle bounces and complaints
- Server maintenance and updates
- Blacklist monitoring
- Limited sending rate initially

---

## Environment Variables

### Complete List

Add these to your production server (e.g., in `.env` file or systemd service):

```bash
# ===================================
# EMAIL CONFIGURATION
# ===================================

# Choose adapter: smtp, mailgun, sendgrid
MAILER_ADAPTER=smtp

# SMTP Settings (for Google Workspace or Self-hosted)
SMTP_RELAY=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=library-system@youruniversity.edu
SMTP_PASSWORD=your_app_password_here
SMTP_SSL=false

# ===================================
# LOAN REMINDER CONFIGURATION
# ===================================

# Days before due date to send reminders (comma-separated)
# Default: 3,1 (3 days before and 1 day before)
LOAN_REMINDER_DAYS=3,1

# Interval in milliseconds (how often to check)
# Default: 86400000 (24 hours)
# Set to 3600000 for hourly checks
LOAN_REMINDER_INTERVAL=86400000
```

### Setting Environment Variables on Ubuntu Server

#### Method 1: Using systemd service

Edit your systemd service file:

```bash
sudo nano /etc/systemd/system/voile.service
```

Add environment variables:

```ini
[Unit]
Description=Voile Library System
After=network.target postgresql.service

[Service]
Type=simple
User=voile
Group=voile
WorkingDirectory=/opt/voile
Environment="PORT=4000"
Environment="PHX_HOST=library.youruniversity.edu"
Environment="PHX_SERVER=true"
Environment="MAILER_ADAPTER=smtp"
Environment="SMTP_RELAY=smtp.gmail.com"
Environment="SMTP_PORT=587"
Environment="SMTP_USERNAME=library-system@youruniversity.edu"
Environment="SMTP_PASSWORD=your_app_password"
Environment="SMTP_SSL=false"
EnvironmentFile=/opt/voile/.env
ExecStart=/opt/voile/bin/voile start
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

#### Method 2: Using .env file

Create `.env` file:

```bash
sudo nano /opt/voile/.env
```

Add variables (see above), then load in systemd:

```ini
EnvironmentFile=/opt/voile/.env
```

#### Method 3: Export in shell profile

```bash
# Add to /etc/environment or ~/.bashrc
export MAILER_ADAPTER=smtp
export SMTP_RELAY=smtp.gmail.com
# ... etc
```

---

## Testing Email

### 1. Test from IEx Console

```bash
# SSH to your server
ssh user@yourserver.com

# Start IEx console
cd /opt/voile
./bin/voile remote

# Test email sending
iex> alias Voile.Mailer
iex> import Swoosh.Email

iex> new()
...> |> to("your-email@example.com")
...> |> from({"Library System", "library-system@youruniversity.edu"})
...> |> subject("Test Email from Production")
...> |> html_body("<h1>Hello!</h1><p>This is a test email.</p>")
...> |> text_body("Hello! This is a test email.")
...> |> Mailer.deliver()
```

### 2. Test Loan Reminder Manually

```elixir
# In IEx console
iex> alias Voile.Schema.Library.Circulation
iex> alias Voile.Notifications.LoanReminderEmail

# Get a test member
iex> member = Voile.Schema.Accounts.get_user(1)

# Get their active loans
iex> transactions = Circulation.list_active_transactions_for_member(member.id)

# Send test reminder
iex> LoanReminderEmail.send_reminder_email(member, transactions, 3)
```

### 3. Test Scheduler

```elixir
# Check if scheduler is running
iex> Process.whereis(Voile.Task.LoanReminderScheduler)
#PID<0.1234.0>  # Should return a PID

# Manually trigger a check
iex> send(Process.whereis(Voile.Task.LoanReminderScheduler), :check_reminders)
```

### 4. Check Logs

```bash
# View application logs
sudo journalctl -u voile -f

# View postfix logs (if self-hosted)
sudo tail -f /var/log/mail.log

# Check for errors
sudo grep error /var/log/mail.log
```

---

## Monitoring & Troubleshooting

### Check Email Delivery Status

#### Google Workspace

1. **Admin Console:**
   - Go to Admin Console → Reports → Email Log Search
   - Track sent, delivered, bounced, or spam emails

2. **Gmail API Monitoring:**
   - Monitor quota usage at https://admin.google.com/
   - Check for any sending limits or warnings

#### Self-Hosted SMTP

```bash
# Check Postfix queue
sudo mailq

# Check mail logs
sudo tail -f /var/log/mail.log

# Test SMTP connection
telnet localhost 25

# Check if port is open
sudo netstat -tuln | grep :25
```

### Common Issues

#### 1. Emails Going to Spam

**For Google Workspace:**
- Already handled by Google ✅

**For Self-hosted:**
```bash
# Check SPF record
dig TXT yourdomain.edu

# Check DMARC record
dig TXT _dmarc.yourdomain.edu

# Test your mail server
# Visit: https://www.mail-tester.com/
# Send test email to provided address
```

#### 2. Authentication Failed

```bash
# Check credentials
echo "SMTP_USERNAME: $SMTP_USERNAME"
echo "SMTP_PASSWORD: $SMTP_PASSWORD"

# Test SMTP auth manually
telnet smtp.gmail.com 587
EHLO yourdomain.edu
STARTTLS
# ... then AUTH LOGIN
```

#### 3. Connection Timeout

```bash
# Check firewall
sudo ufw status

# Allow SMTP ports
sudo ufw allow 25/tcp
sudo ufw allow 587/tcp

# Check if port is reachable
nc -zv smtp.gmail.com 587
```

#### 4. Rate Limiting

**Google Workspace:**
- Monitor daily sending in Admin Console
- Spread emails throughout the day
- Consider multiple sender accounts if needed

**Self-hosted:**
```bash
# Check rate limits in Postfix
sudo postconf | grep rate

# Adjust if needed
sudo postconf -e 'smtpd_client_message_rate_limit = 100'
sudo postfix reload
```

### Email Deliverability Checklist

- [ ] Valid SPF record configured
- [ ] DKIM signing enabled
- [ ] DMARC policy set
- [ ] Reverse DNS (PTR) record set
- [ ] SSL/TLS certificate valid
- [ ] Not on any blacklists (check: https://mxtoolbox.com/blacklists.aspx)
- [ ] Proper unsubscribe mechanism
- [ ] Bounce handling configured
- [ ] Valid "From" address
- [ ] Proper email headers

---

## Recommendation

### For Your University Library System:

**Use Google Workspace SMTP** ✅

**Reasons:**
1. ✅ 20k emails/day = 600k/month (30x your max needs!)
2. ✅ Already paid for (zero additional cost)
3. ✅ High deliverability (99%+ delivery rate)
4. ✅ 5-minute setup vs hours for self-hosted
5. ✅ No maintenance or monitoring needed
6. ✅ Professional appearance (university domain)
7. ✅ Built-in security and compliance

**Setup Time:**
- Google Workspace: **5 minutes** ⚡
- Self-hosted SMTP: **4-8 hours** + ongoing maintenance 😰

**Cost:**
- Google Workspace: **$0** (already have it)
- Self-hosted: Server time, maintenance, potential blacklist issues

**Deliverability:**
- Google Workspace: **99%+** (Gmail's reputation)
- Self-hosted: **60-80%** initially (need to build reputation)

---

## Quick Start (Google Workspace)

```bash
# 1. Generate app password in Google Admin
# 2. Add to server environment:
export MAILER_ADAPTER=smtp
export SMTP_RELAY=smtp.gmail.com
export SMTP_PORT=587
export SMTP_USERNAME=library-system@youruniversity.edu
export SMTP_PASSWORD=your_app_password

# 3. Update email "from" address in code
# Edit: lib/voile/notifications/loan_reminder_email.ex
# Change: from({"Library System", "noreply@library.system"})
# To:     from({"University Library", "library-system@youruniversity.edu"})

# 4. Deploy and test
./bin/voile restart

# 5. Test in IEx
./bin/voile remote
# Send test email (see Testing section above)
```

You should be sending emails in production within 10 minutes! 🎉
