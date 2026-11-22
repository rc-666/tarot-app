#!/usr/bin/env bash
# Applies the init migration to a scratch local Postgres with Supabase stand-ins and runs the access-rule checks.
# Expected: T2, T3, T4, T6 and the second rating in T7 print ERROR; T1/T9 print t; T5 = 1|1|0; T10 = 1|0; T11 = 0|0.
set -e
cd "$(dirname "$0")/.."
dropdb --if-exists tarot_test && createdb tarot_test
psql -q -d tarot_test -v ON_ERROR_STOP=1 -f tests/supabase_stub.sql -f migrations/20261122000001_init.sql
psql -q -d tarot_test -f tests/rls_test.sql
