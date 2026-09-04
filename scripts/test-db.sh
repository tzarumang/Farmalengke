#!/usr/bin/env bash
#
# Applies the migrations to a throwaway PostgreSQL database and runs the row-level
# security tests against them.
#
# This deliberately does not need Docker or the Supabase stack: it runs against any
# PostgreSQL 15+ server, using a shim that reproduces the parts of Supabase's `auth`
# schema the policies depend on. That keeps the security tests runnable in CI.
#
# Usage:
#   scripts/test-db.sh                 # uses PGHOST/PGPORT/PGUSER from the environment
#   PGPORT=55432 scripts/test-db.sh

set -euo pipefail

DB_NAME="${FARMALENGKE_TEST_DB:-farmalengke_rls_test}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PGDATABASE=postgres

echo "==> Recreating ${DB_NAME}"
psql -q -v ON_ERROR_STOP=1 -c "drop database if exists ${DB_NAME};" >/dev/null
psql -q -v ON_ERROR_STOP=1 -c "create database ${DB_NAME};" >/dev/null

export PGDATABASE="${DB_NAME}"

echo "==> Installing the Supabase auth shim (test support only)"
psql -q -v ON_ERROR_STOP=1 -f "${ROOT}/supabase/tests/00_auth_shim.sql"

echo "==> Applying migrations"
for migration in "${ROOT}"/supabase/migrations/*.sql; do
  echo "    $(basename "${migration}")"
  psql -q -v ON_ERROR_STOP=1 -f "${migration}"
done

echo "==> Applying table grants (as Supabase would)"
psql -q -v ON_ERROR_STOP=1 -f "${ROOT}/supabase/tests/01_grants.sql"

echo "==> Running row-level security tests"
# Every NN_*_test.sql runs, in order. psql exits non-zero on a raised exception,
# so a failed assertion fails the script — which is what makes these tests real.
shopt -s nullglob
for suite in "${ROOT}"/supabase/tests/[0-9][0-9]_*_test.sql; do
  echo "    $(basename "${suite}")"
  psql -v ON_ERROR_STOP=1 -f "${suite}" 2>&1 \
    | sed -E 's/^psql:[^ ]+ (NOTICE|INFO):  //'
done

echo "==> Dropping ${DB_NAME}"
export PGDATABASE=postgres
psql -q -v ON_ERROR_STOP=1 -c "drop database if exists ${DB_NAME};" >/dev/null
