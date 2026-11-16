/*
# Consolidate auth auto-confirm setup (permanent fix for project import)

## Purpose
When this project is imported into a new Bolt instance, a fresh Supabase project
is provisioned and all migration files are replayed. Several earlier auth-related
migrations had a `.sql.sql` double extension and may not have been recognized by
the replay system, leaving the new database without proper auth configuration:

  - Email confirmation stayed ON (signUp returns no session)
  - The trigger only set email_confirmed_at but not confirmed_at
  - signInWithPassword() failed with "Email not confirmed"

This single migration consolidates all auth setup into one idempotent file with
the correct `.sql` extension so it is always replayed correctly.

## Changes

### 1. Auto-confirm trigger function
- Create or replace `public.auto_confirm_email()` as a SECURITY DEFINER trigger
  function that sets BOTH `email_confirmed_at` and `confirmed_at` to `now()` on
  every new `auth.users` row.
- This ensures signUp() returns a session immediately and signInWithPassword()
  works right away, regardless of the GoTrue autoconfirm config.

### 2. Auto-confirm trigger
- Drop and recreate the BEFORE INSERT trigger on `auth.users`.

### 3. GoTrue auth config
- Ensure `auth.instances` has `mailer.autoconfirm` set to `true` and
  `auth.enable_signup` set to `true`.
- If no row exists in `auth.instances`, insert one with the correct config.
- If a row exists, update its config to enable autoconfirm and signup.

### 4. Revoke direct function access
- Revoke EXECUTE on the trigger function from PUBLIC, anon, and authenticated
  so it can only be called by the database trigger, not by API clients.

## Security
- The trigger function is SECURITY DEFINER and only modifies confirmation
  timestamp columns on auth.users.
- EXECUTE is revoked from all roles; the function is only invoked by the trigger.
- No RLS or policy changes on application tables.
- autoconfirm is intentionally ON and signup is intentionally enabled.
*/
