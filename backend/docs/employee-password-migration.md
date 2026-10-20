# Employee password migration

Employee logins use the bcrypt password hash stored in Neon `public.app_user`. To preserve an existing password, an authorized database administrator must migrate the original bcrypt hash from the legacy Supabase `public.app_user` record to the corresponding Neon record. Never migrate plaintext passwords, print hashes, or commit credentials. Verify the username and role on both sides, perform the change in a transaction, and test authentication after deployment. If the source is not a compatible bcrypt hash, use the password reset flow instead.
