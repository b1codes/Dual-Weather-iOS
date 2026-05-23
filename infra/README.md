# Dual Weather Infra

Terraform code for the AWS + Auth0 resources backing the Dual Weather API.

Three root modules, each with its own state file:

- `bootstrap/` — one-time: S3 state bucket + DynamoDB lock table (local state).
- `platform/` — long-lived identity resources (Auth0). Created in Plan 2.
- `runtime/` — disposable compute (DynamoDB, Lambda, API Gateway). Created in Plan 2.

Region: `us-east-2`.

See `docs/superpowers/specs/2026-05-23-backend-infra-extraction-design.md` for full design.
