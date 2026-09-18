#!/usr/bin/env bash
# Apply the migrations to a scratch Postgres and run the RLS test suite.
#
# Uses a local Postgres from the conda env rather than a container: rootless
# podman cannot map the UIDs Postgres needs on this machine's NFS-backed storage.
#
#   ./supabase/tests/run.sh
set -euo pipefail

PORT="${PGPORT:-55432}"
PGDATA="${PGDATA:-/tmp/qpg-$USER}"
DB=questrium_test
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

source ~/miniconda3/etc/profile.d/conda.sh
conda activate questrium

if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  echo "starting postgres in $PGDATA"
  [ -d "$PGDATA" ] || initdb -D "$PGDATA" -U postgres --auth=trust >/dev/null
  pg_ctl -D "$PGDATA" -o "-p $PORT -k /tmp -c listen_addresses=''" -l /tmp/qpg.log start >/dev/null
  sleep 2
fi

q() { psql -h /tmp -p "$PORT" -U postgres "$@"; }

q -d postgres -q -c "drop database if exists $DB;" -c "create database $DB;"

for f in "$HERE/00_supabase_shim.sql" "$ROOT"/supabase/migrations/*.sql; do
  printf '  %-42s' "$(basename "$f")"
  if q -d "$DB" -v ON_ERROR_STOP=1 -q -f "$f" >/dev/null 2>&1; then
    echo "ok"
  else
    echo "FAILED"; q -d "$DB" -v ON_ERROR_STOP=1 -q -f "$f" 2>&1 | head -20; exit 1
  fi
done

echo
q -d "$DB" -v ON_ERROR_STOP=1 -q -f "$HERE/01_rls_test.sql" 2>&1 \
  | sed 's/^psql.*NOTICE:  //; s/^NOTICE:  //'
