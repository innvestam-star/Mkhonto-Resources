# Mkhonto Resources

**We Moving Value**

This repository is connected to the existing **Mkhonto Resources Hub** Supabase project.

## Supabase project

- Project name: `Mkhonto Resources Hub`
- Project reference: `zjrzzvakwrwkrcqhcnyo`
- Region: `eu-west-2`
- Public API URL: `https://zjrzzvakwrwkrcqhcnyo.supabase.co`
- Environment template: `.env.example`
- Local Supabase configuration: `supabase/config.toml`

The browser-safe project URL and publishable key are recorded in `.env.example`. Server keys, access tokens, and the database password must remain in local environment files or encrypted deployment/GitHub secrets.

## Restore the repository connection

Create these encrypted GitHub Actions secrets under **Settings → Secrets and variables → Actions**:

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_DB_PASSWORD`

Then run the **Recover hosted Supabase schema** workflow from the GitHub Actions tab. It will:

1. Link this repository to the hosted project.
2. Pull the hosted database schema and migration baseline.
3. Generate `src/types/database.types.ts`.
4. Commit the recovered files to `main`.

You can perform the same operation locally:

```bash
export SUPABASE_ACCESS_TOKEN="your-personal-access-token"
export SUPABASE_DB_PASSWORD="your-project-database-password"
bash scripts/bootstrap-supabase.sh
```

## Automated checks

- `verify-supabase.yml` checks the REST API, Auth health endpoint, and Google verification file.
- `update-supabase-types.yml` regenerates database types weekly after `SUPABASE_ACCESS_TOKEN` has been added.
- `recover-supabase-schema.yml` performs the one-time hosted schema recovery.

## Google Search Console

The uploaded verification file is committed at the repository root:

```text
google0f5aff3a23595204.html
```

The deployment must serve it at the website root as:

```text
https://mkhontoresources.com/google0f5aff3a23595204.html
```

Do not rename the file or alter its contents.
