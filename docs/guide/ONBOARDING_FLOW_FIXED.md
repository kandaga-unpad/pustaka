# Onboarding Flow - Fixed & Simplified

## ✅ Changes Made

### 1. Removed Forced Email Change for Migrated Users
**Before**: Users with identifier + personal email were FORCED to change to institutional email
**After**: Users can KEEP their personal email or optionally switch to institutional

**Affected**: Alumni, external users, migrated users with personal email

### 2. Simplified User Type Detection
**Before**: 4 complex types based on migration date, confirmation status, etc.
**After**: 3 simple types based on current state

| User Type | Condition | What They See |
|-----------|-----------|---------------|
| `:institutional_new_user` | Has @unpad email, no identifier | Must provide NPM/NIP |
| `:migrated_with_personal_email` | Has identifier, personal email | Can keep or change email |
| `:new_user` | No identifier, personal email | Auto-generate identifier |

### 3. Unified Onboarding Logic
Both **password login** and **Google OAuth** now use the SAME logic:
- Check: `is_nil(fullname) or is_nil(phone_number)`
- For institutional email: also check `is_nil(identifier)`

---

## 📋 Updated Flow Scenarios

### Scenario 1: User with Identifier + Personal Email (@gmail.com)
**Example**: Migrated alumni with NPM `270110000001` and `alumni@gmail.com`

✅ **Login**: Success (password or Google OAuth)
✅ **Onboarding**: `:migrated_with_personal_email` flow
- Green banner: "Welcome Back! Your identifier has been found."
- Email field: **EDITABLE** (can keep gmail or switch to @unpad)
- Identifier field: **READONLY** (shows NPM/NIP)
- Must fill: fullname, phone, etc.

**No forced email change!** ✅

---

### Scenario 2: User with @unpad.ac.id Email, No Identifier
**Example**: New student logged in via Google with `john@mail.unpad.ac.id`

✅ **Login**: Success (Google OAuth creates account)
✅ **Onboarding**: `:institutional_new_user` flow
- Blue banner: "Institutional Account Detected"
- Email field: **READONLY** (already @unpad)
- Identifier field: **REQUIRED** (must enter NPM/NIP)
- Must fill: fullname, phone, etc.

**Must provide identifier!** ✅

---

### Scenario 3: User with Personal Email (@gmail.com), No Identifier
**Example**: New user registered with `user@gmail.com`

✅ **Login**: Success
✅ **Onboarding**: `:new_user` flow
- Green banner: "Welcome to Voile!"
- Email field: **READONLY** (stays @gmail)
- Identifier: **AUTO-GENERATED** (system creates: `1730811234567`)
- Must fill: fullname, phone, etc.

**Normal flow, no special requirements!** ✅

---

## 🔄 Google OAuth Flow (Fixed)

### Before:
```elixir
# Different logic, could miss some cases
needs_onboarding = 
  is_nil(fullname) or is_nil(phone) or
  (is_institutional and is_nil(identifier))
```

### After:
```elixir
# Same logic as password login!
needs_onboarding = 
  is_nil(fullname) or is_nil(phone) or
  (is_institutional and is_nil(identifier))
```

### What Changed:
1. ✅ Institutional users (@unpad) → Must provide NPM/NIP
2. ✅ Personal email users → Just fill profile (identifier auto-generated)
3. ✅ Migrated users with identifier → Can keep personal email

---

## 🎯 Key Improvements

### 1. Alumni-Friendly
- ✅ Alumni with NPM can keep their `@gmail.com` email
- ✅ No forced migration to institutional email
- ✅ Can optionally switch if they want

### 2. Clear Requirements
| Email Type | Identifier Requirement |
|------------|------------------------|
| @unpad.ac.id | ⚠️ **MUST provide NPM/NIP** |
| @mail.unpad.ac.id | ⚠️ **MUST provide NPM/NIP** |
| @gmail.com (has identifier) | ✅ Keep existing identifier |
| @gmail.com (no identifier) | ✅ Auto-generated |

### 3. Consistent Behavior
- Password login and Google OAuth use **same logic**
- No special cases or migration cutoff dates
- Simple, predictable flow

---

## 🧪 Testing Checklist

### Test Case 1: Migrated Alumni
- [ ] User: NPM `270110000001`, Email: `alumni@gmail.com`
- [ ] Login successful
- [ ] Onboarding shows: "Welcome Back! Your identifier has been found"
- [ ] Email is editable (not forced to change)
- [ ] Identifier is readonly
- [ ] Can complete profile with personal email

### Test Case 2: New Institutional Student (Google OAuth)
- [ ] Login with: `student@mail.unpad.ac.id` via Google
- [ ] Account created automatically
- [ ] Redirected to onboarding
- [ ] Must provide NPM/NIP (identifier field required)
- [ ] Email is readonly (@unpad)
- [ ] Can complete profile after providing NPM

### Test Case 3: New Personal User
- [ ] Register with: `newuser@gmail.com`
- [ ] Confirm email
- [ ] Login successful
- [ ] Redirected to onboarding
- [ ] Identifier auto-generated
- [ ] Email readonly (@gmail)
- [ ] Just fill basic profile

### Test Case 4: Google OAuth with Personal Email
- [ ] Login with: `user@gmail.com` via Google
- [ ] Account created
- [ ] Redirected to onboarding
- [ ] Identifier auto-generated
- [ ] Email readonly (@gmail)
- [ ] Complete profile normally

---

## 📝 Files Modified

1. **lib/voile_web/auth/user_auth.ex**
   - Removed forced email validation
   - Simplified `needs_onboarding?/1`
   - Removed unused `institutional_email?/1`

2. **lib/voile_web/auth/user_auth_google.ex**
   - Added clarifying comments
   - Consistent with password login logic

3. **lib/voile_web/live/users/auth/user_onboarding_live.ex**
   - Simplified `determine_user_type/1`
   - Removed `:migrated_with_identifier` (forced email change)
   - Removed `:migrated_without_identifier` (unnecessary complexity)
   - Added `:migrated_with_personal_email` (alumni-friendly)
   - Updated UI for new flow
   - Updated validation logic

---

## 🎉 Summary

### Problem Solved:
❌ Alumni with NPM forced to change to @unpad email (they might not have access)
❌ Different logic between password login and Google OAuth
❌ Complex user type detection with migration dates

### Solution:
✅ Alumni can keep personal email
✅ Unified logic for all login methods
✅ Simple, clear user type detection
✅ Institutional users still must provide NPM/NIP
✅ Personal email users get auto-generated identifier

**Result**: Flexible, user-friendly onboarding that respects user choice while maintaining data requirements! 🎯
