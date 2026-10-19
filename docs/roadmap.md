# Roadmap and known gaps

## Not built yet

- **Code exercises.** The `type` field exists for them; see courses.md for what a new type needs. Evaluating code safely needs a sandboxed runner, probably as a Sidekiq job.
- **Email confirmation.** Anyone can register any email address. It cannot be used to get into an existing account, but it can squat an address.
- **Account recovery.** A learner who loses their passkey loses the account. Needs email sending first.
- **More than one passkey per account**, to add a device whose passkeys are not synced. Registration currently refuses a learner that already has an email.
- **Cleaning up abandoned learners.** Every first visit creates a learner and a session, and logging in leaves the anonymous one behind. Nothing deletes them. A periodic job could delete learners with no email, no completions and no revisions after some weeks.
- **Session expiry.** Sessions never expire.
- **Rate limiting.** `POST /learners` and the passkey endpoints accept any number of requests.
- **Production deployment** and its configuration (`FRONTEND_HOST`, WebAuthn settings, database credentials).
- **CI.** The inherited GitHub Actions, CircleCI and GitLab configurations have not been checked against Manabase.

## Known problems

- `heighliner db_save` fails and leaves the database stopped; `manabe-redis` does not resolve. See development.md.
- On 2026-10-17 a browser tab running an old frontend against a newer backend created about 54,000 anonymous learners in twelve minutes (its retry loop had no limit). The frontend now starts over at most once per page load. The rows are still in the development database: learners with no email, no completions and no revisions, created between 07:43 and 07:55 UTC.
