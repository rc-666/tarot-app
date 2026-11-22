-- Daily sky job: 05:00 UTC, before 06:00 local in Brazil's earliest zone (Noronha, UTC-2 = 08:00 UTC).
-- Calls the compute-sky Edge Function, which computes today + tomorrow for every supported time zone,
-- personal cards for every saved profile, and mood shifts for the next 8 days. Idempotent (upserts).
--
-- One-time setup per project (Dashboard > SQL editor), not stored in git:
--   select vault.create_secret('https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret('<service-role-key>', 'service_role_key');

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'compute-sky-daily',
  '0 5 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/compute-sky',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);

-- Retry at 06:00 UTC in case the first run failed (still before 08:00 UTC). Upserts make a double run harmless.
select cron.schedule(
  'compute-sky-retry',
  '0 6 * * *',
  $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/compute-sky',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
