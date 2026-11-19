#!/usr/bin/env bash
# Corre las pruebas pgTAP con psql, sin la imagen pg_prove. Útil donde esa
# imagen no se puede descargar. Uso: tools/pgtap.sh [archivo.sql ...]
set -u
DB="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
psql -X -q "$DB" -c "create extension if not exists pgtap with schema extensions" >/dev/null 2>&1
files=("$@"); [ ${#files[@]} -eq 0 ] && files=(supabase/tests/*.sql)
fail=0
for f in "${files[@]}"; do
  out=$(psql -X -q -v ON_ERROR_STOP=1 "$DB" -f "$f" 2>&1)
  plan=$(echo "$out" | grep -oE '^ *1\.\.[0-9]+' | head -1 | tr -d ' ')
  oks=$(echo "$out" | grep -cE '^ *ok [0-9]+')
  bad=$(echo "$out" | grep -E '^ *not ok|ERROR|# Looks like')
  if [ -n "$bad" ]; then fail=1; echo "FALLA $f ($plan, $oks ok)"; echo "$bad" | head -20
    echo "$out" | grep -A4 "not ok" | grep "#" | head -20
  else echo "ok    $f ($plan, $oks ok)"; fi
done
exit $fail
