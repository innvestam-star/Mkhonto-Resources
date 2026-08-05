# Hosted migration manifest

The active hosted project is **Mkhonto Resources Hub** with project reference `zjrzzvakwrwkrcqhcnyo`.

The hosted database currently records these applied migrations:

| Version | Migration |
|---|---|
| `20260803202920` | `mkhonto_hub_phase_4_foundation` |
| `20260803203051` | `mkhonto_hub_fk_indexes` |
| `20260805191833` | `auth_access_and_protected_route_foundation` |
| `20260805191850` | `restrict_auth_rpc_execution` |

The original repository was deleted, so the SQL migration files must be recovered from the hosted project before new schema changes are committed.

Run `scripts/bootstrap-supabase.sh` with `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` set. The script links this repository, pulls the hosted schema into `supabase/migrations`, and regenerates `src/types/database.types.ts`.

Do not create a fresh baseline manually or run `supabase db push` until the recovered migration history has been reviewed and committed.
