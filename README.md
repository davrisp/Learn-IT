# Learn-It

Study app (flashcards, match, tests, spaced repetition). Stack: Supabase (Postgres, Auth, RLS) + Next.js (next).

## Local development
1. Install Docker and the Supabase CLI.
2. `supabase start` then `supabase db reset` (applies migrations).
3. `supabase test db` runs the access-control tests. Run them before every PR.
4. `prototype/index.html` is the standalone UI prototype (works offline, no backend).

## Security rules (do not break)
- Every table has RLS enabled. New table = RLS + policies + grants in the same migration.
- `service_role` key: server only, never in the browser or repo.
- Clients cannot read `set_share_links` or write `card_progress`; they use RPCs
  (`create_share_link`, `get_set_by_link`, `review_card`, `export_my_data`, `delete_my_account`).

## GitHub setup
- Repo secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`.
- Create an Environment named `production` with required reviewers.
- Branch protection on `main`: require PR, require the CI checks, block force pushes.
- Enable: secret scanning + push protection, Dependabot alerts, private vulnerability reporting.
- Sign in with GitHub: create a GitHub OAuth App, set the callback to
  `https://<project-ref>.supabase.co/auth/v1/callback`, add client id/secret in Supabase Auth settings.
