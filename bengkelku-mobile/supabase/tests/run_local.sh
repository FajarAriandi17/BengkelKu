#!/usr/bin/env bash
# Jalankan semua migrasi + uji SQL pada PostgreSQL + PostGIS lokal (tanpa Supabase CLI).
# Pemakaian: PGHOST=/var/run/postgresql bash supabase/tests/run_local.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
DB=${DB:-bk_test}

fresh_db() {
  dropdb --if-exists "$DB" >/dev/null 2>&1 || true
  createdb "$DB"
  # Role anon/authenticated/service_role bersifat global; buat bila belum ada.
  psql -q -d "$DB" -c "do \$\$ begin
    if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
    if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
    if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
  end \$\$;" >/dev/null
  sed -e "s/^alter database bk /alter database $DB /" -e '/^create role anon/d' supabase/tests/local_supabase_stub.sql \
    | psql -q -v ON_ERROR_STOP=1 -d "$DB" >/dev/null
  for f in supabase/migrations/*.sql; do
    psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f" >/dev/null 2>/tmp/bk_mig_err \
      || { echo "MIGRASI GAGAL: $f"; cat /tmp/bk_mig_err; exit 1; }
  done
  psql -q -v ON_ERROR_STOP=1 -d "$DB" -f supabase/seed.sql >/dev/null
}

for t in sos_flow_smoke.sql sos_owner_side_test.sql; do
  fresh_db
  out=$(psql -v ON_ERROR_STOP=1 -d "$DB" -f "supabase/tests/$t" 2>&1) || { echo "$out" | tail -20; echo "UJI GAGAL: $t"; exit 1; }
  echo "$out" | grep -E "SMOKE_OK|OWNER_SIDE_OK"
done
echo "SEMUA UJI SQL LULUS"
