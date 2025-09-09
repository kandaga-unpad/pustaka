# Member Onboarding System

This document explains the member onboarding system for users migrated from the previous system.

## Overview

The onboarding system allows migrated members to securely set their passwords and activate their accounts using magic links. All migrated users have their password set to `"changeme123"` and their accounts are unconfirmed until they complete the onboarding process.

## Features

### 1. Magic Link Onboarding
- Migrated users receive an email with a secure onboarding link
- The link allows them to set a new password without needing the old one
- Account is automatically confirmed once password is set
- Old sessions and tokens are invalidated for security

### 2. Admin Management Interface
- Admins can view all users requiring onboarding at `/manage/settings/users/onboarding/manage`
- Send individual or bulk onboarding emails
- Track onboarding completion status
- Refresh user list to see updates

### 3. Improved Login Experience
- Login page offers "login with email link" option
- Automatically detects migrated users and sends appropriate emails
- Clear messaging about the onboarding process

### 4. Command Line Tools
- `mix voile.send_onboarding_emails` - Send emails to all users needing onboarding
- `mix voile.send_onboarding_emails --dry-run` - Preview users without sending emails
- `mix voile.send_onboarding_emails --limit 10` - Send to only first 10 users

## User Flow

### For Migrated Users:

1. **User attempts to login** with their email
2. **User clicks "login with email link"** instead of entering password
3. **System detects** user needs onboarding (unconfirmed + default password)
4. **Onboarding email sent** with secure link
5. **User clicks link** and is taken to onboarding page
6. **User sets new password** and confirms account
7. **User is redirected** to login page to sign in

### For Admins:

1. **Go to** `/manage/settings/users/onboarding/manage`
2. **View list** of users needing onboarding
3. **Send emails** individually or in bulk
4. **Monitor progress** as users complete onboarding

## Security Features

- **Unique tokens**: Each onboarding link has a unique, cryptographically secure token
- **Time expiration**: Onboarding links expire after 24 hours  
- **Single use**: Tokens are deleted after successful use
- **Password requirements**: New passwords must meet security requirements
- **Account confirmation**: Accounts are automatically confirmed after password reset
- **Session invalidation**: All old sessions are invalidated during onboarding

## Technical Implementation

### Key Components:

1. **VoileWeb.UserOnboardingLive** - Main onboarding interface
2. **VoileWeb.Users.OnboardingManageLive** - Admin management interface  
3. **Accounts.deliver_onboarding_instructions/2** - Send onboarding emails
4. **Accounts.complete_user_onboarding/2** - Complete the onboarding process
5. **User.onboarding_changeset/3** - Validate and update user during onboarding
6. **Mix.Tasks.Voile.SendOnboardingEmails** - Command line email sender

### Database Considerations:

- Users with `confirmed_at: nil` are considered unconfirmed
- Default password hash identifies migrated users
- Onboarding tokens use "onboarding" context for security isolation

## Usage Examples

### Send onboarding emails via command line:
```bash
# Preview users who need onboarding
mix voile.send_onboarding_emails --dry-run

# Send to first 5 users (for testing)
mix voile.send_onboarding_emails --limit 5

# Send to all users needing onboarding  
mix voile.send_onboarding_emails
```

### Send via admin interface:
1. Visit `/manage/settings/users/onboarding/manage`
2. Click "Send All Onboarding Emails" or send individually

### User onboarding:
1. User receives email with subject "Welcome to Voile - Set Your Password"
2. User clicks the onboarding link
3. User sets new password on secure onboarding page
4. User is confirmed and redirected to login

## Email Templates

The system sends different types of emails:

- **Onboarding email**: For migrated users setting their first password
- **Magic link email**: For confirmed users who want passwordless login  
- **Password reset email**: For users who forgot their password

## Customization

### Email Content:
Edit `UserNotifier.deliver_onboarding_instructions/2` to customize email content.

### Onboarding Page:
Modify `VoileWeb.UserOnboardingLive` to change the onboarding interface.

### Admin Interface:
Update `VoileWeb.Users.OnboardingManageLive` to add more management features.

## Troubleshooting

### Common Issues:

1. **Emails not sending**: Check email configuration in config files
2. **Links expired**: Links expire in 24 hours, send new ones if needed
3. **Users not found**: Make sure migration completed and users have default password hash
4. **Token invalid**: Tokens are single-use, user may have already completed onboarding

### Monitoring:

- Check logs for email sending errors
- Use admin interface to see current onboarding status
- Run `--dry-run` to preview users before sending emails

## Related Files

- `/lib/voile_web/live/users/user_onboarding_live.ex` - Onboarding interface
- `/lib/voile_web/live/users/onboarding_manage_live.ex` - Admin interface
- `/lib/voile/schema/accounts.ex` - Account management functions
- `/lib/voile/schema/accounts/user.ex` - User schema and changesets
- `/lib/voile/schema/accounts/user_notifier.ex` - Email templates
- `/lib/mix/tasks/send_onboarding_emails.ex` - Command line tool
- `/lib/voile_web/controllers/magic_link_controller.ex` - Magic link login
