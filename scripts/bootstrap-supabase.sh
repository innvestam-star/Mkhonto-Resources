#!/usr/bin/env bash
set -euo pipefail

PROJECT_REF="${SUPABASE_PROJECT_REF:-zjrzzvakwrwkrcqhcnyo}"

if ! command -v npx >/dev/null 2>&1; then
  echo "Node.js and npm are required."
  exit 1
fi

if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "Set SUPABASE_ACCESS_TOKEN before running this script."
  exit 1
fi

if [ -z "${SUPABASE_DB_PASSWORD:-}" ]; then
  echo "Set SUPABASE_DB_PASSWORD before running this script."
  exit 1
fi

if [ ! -f supabase/config.toml ]; then
  npx supabase init
fi

npx supabase link \
  --project-ref "$PROJECT_REF" \
  --password "$SUPABASE_DB_PASSWORD"

# Recover the authoritative hosted schema into a migration file.
npx supabase db pull

# Keep application types aligned with the hosted public schema.
mkdir -p src/types
npx supabase gen types typescript \
  --project-id "$PROJECT_REF" \
  --schema public \
  > src/types/database.types.ts

echo "Supabase project linked and schema recovered for $PROJECT_REF."
