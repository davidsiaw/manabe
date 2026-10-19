# Architecture

## Layout

```
app/apis/                  Grape APIs. Everything students use is under /api/v1.
  root_api.rb              Mounted at / in config/routes.rb. Swagger docs and the 404 catch-all.
  main_api.rb              /api, with V1Api mounting every v1 API.
  v1_api/
    health_api.rb          GET /health
    learners_api.rb        POST /learners: anonymous learners
    account_api.rb         /me, /registration, /login, /session
    courses_api.rb         /courses, a course's tree, progress, revisions
    problems_api.rb        A problem, and answering it
    auth_helpers.rb        current_learner / optional_learner from the bearer token
    course_api_helpers.rb  Course lookup and the JSON shapes shared by the course APIs
app/models/                Learner, LearnerSession, Passkey, PasskeyChallenge, Completion, Revision;
                           Admin (devise, template), PaperTrail::Version (template)
app/services/
  course_catalog.rb        Loads courses from courses/ (with course_catalog/*.rb)
  course_progress.rb       A learner's progress through one course, per round
  passkey_ceremony.rb      Passkey registration and login (WebAuthn)
courses/                   The courses, as YAML. See courses/README.md.
config/initializers/
  webauthn.rb              Which site passkeys belong to
  cors.rb                  Allowed frontend origin
db/migrate/, db/schema.rb  The schema. See data-model.md.
spec/                      RSpec. See testing.md.
docs/                      These notes.
Heighliner.config          The dev environment. See development.md.
```

## Request flow

Rails routes everything except `/swagger`, `/sidekiq` and the devise admin pages to `RootApi` (`config/routes.rb`), which mounts `MainApi` (`/api`), which mounts the v1 APIs. Each API declares its helpers explicitly:

```ruby
class ProblemsApi < Grape::API
  helpers AuthHelpers, CourseApiHelpers
  rescue_from(CourseCatalog::NotFound) { error!({ error: :not_found }, 404) }
  ...
end
```

- **Authentication** is `current_learner` (401 without a valid session) or `optional_learner` (nil without one), from `AuthHelpers`. See accounts.md.
- **Errors** are `error!({ error: :some_code }, status)`, so every error body is `{"error": "some_code"}`. The frontend switches on those codes, so treat them as part of the API.
- **Logic lives in services and models**, not in the API classes: `CourseCatalog`, `CourseProgress` and `PasskeyCeremony` are tested directly, and the API specs check the HTTP side.
- New API files go in `app/apis/v1_api/` and are mounted in `main_api.rb`. Files there are autoloaded as top-level constants (`HealthApi`, not `V1Api::HealthApi`), because `config/application.rb` adds each `app/apis/*` directory to the autoload paths. A new directory under `app/apis/` needs a server restart to be picked up.

## Conventions

- Primary keys are ULIDs, stored in `uuid` columns. Read data-model.md before adding a table or a reference.
- Tables have `updated_at` but no `created_at`: the ULID id records creation time, and `ApplicationRecord` derives `created_at` from it.
- RuboCop with the rails, rspec, factory_bot and capybara plugins: `bundle exec rubocop` must be clean. Prefer restructuring over raising limits; the limits in `.rubocop_todo.yml` predate Manabase.
- Comments explain *why*. Code that looks odd but is deliberate says so, with the reason.
- New dependencies need a reason, written next to them in the Gemfile (see `webauthn`).

## From the rails-zen template

The repository started as [rails-zen](https://github.com/davidsiaw/rails-zen), a Rails API skeleton, renamed to Manabase with `bin/rename manabase` (which replaces `rails_zen`/`RailsZen` in every non-hidden file; it can be run again to rename further). Still in place from the template:

- Swagger UI at `/swagger` and the Sidekiq dashboard at `/sidekiq`, both behind a devise login for `Admin` (seeded as `admin@example.com` / `asdasd`).
- PaperTrail (`versions` table), Sidekiq with sidekiq-scheduler, async-redis, Falcon.
- `docker-compose.yml` and the `bin/start`, `bin/stop`, `bin/test` and similar scripts, which run the stack with docker compose instead of heighliner. Manabase development uses heighliner; the compose setup has not been kept up to date with Manabase (it knows nothing of `courses/` or the WebAuthn settings).
- CI configurations: `.github/workflows/`, `.circleci/` (including vulnerability scanners) and `.gitlab-ci.yml`. They are inherited and have not been checked against Manabase.
- A generator for new APIs: `rails g api Name` (`lib/generators/api`).
