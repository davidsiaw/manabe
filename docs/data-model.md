# Data model

Courses are not in the database: they are YAML files (see courses.md), and the database refers to courses and problems by their slugs. Everything else is in PostgreSQL. `db/schema.rb` is the source of truth; this is the map.

```
learners ──< learner_sessions        a browser's bearer token, as a digest
    │  ├──< passkeys                 registered passkeys
    │  ├──< completions              solved problems, per course and round
    │  ├──< revisions                rounds >= 2, per course
    │  └──< passkey_challenges       pending WebAuthn challenges (learner optional)
admins, versions                     from the rails-zen template
```

| Table | Columns | Notes |
|---|---|---|
| `learners` | `email` (citext, unique, nullable), `webauthn_id` (unique, nullable) | No email means anonymous. `webauthn_id` is the WebAuthn user handle, set when registration starts. |
| `learner_sessions` | `learner_id`, `token_digest` (unique) | SHA-256 hex of the bearer token. Deleted on logout. |
| `passkeys` | `learner_id`, `external_id` (unique, the credential id), `public_key`, `sign_count` | Both binary values are base64url text, as the webauthn gem encodes them. |
| `passkey_challenges` | `challenge` (unique), `purpose` (`registration` or `login`), `learner_id` (nullable), `email`, `expires_at` | One use, five minutes. Expired rows are deleted whenever a new challenge is issued. |
| `completions` | `learner_id`, `course_id`, `problem_id`, `round` (default 1) | Unique on learner, course, round and problem. |
| `revisions` | `learner_id`, `course_id`, `number` (>= 2) | Unique on learner, course and number. |

`course_id` and `problem_id` are slugs, not foreign keys. Rows for courses or problems that no longer exist stay in the table and are ignored when progress is computed.

## IDs are ULIDs in uuid columns

`ApplicationRecord` includes `ULID::Rails` (from the `davidsiaw/ulid-rails` fork) and declares `ulid :id`. Every table is created with `id: :uuid`; the gem converts between the ULID string the app sees (Crockford base32) and the uuid PostgreSQL stores.

- IDs are **not always 26 characters**: the conversion drops leading zeros. Do not validate them as exactly 26 characters.
- Creation time is encoded in the id, so tables have no `created_at` (only `updated_at`), and `record.created_at` is derived from the id.

## Declaring references: two traps

`ulid :column` does more than set the type:

1. It adds a `before_create` that fills the column with a **random ULID if it is nil**. For an optional reference that means a nonsense foreign key and a `ForeignKeyViolation`.
2. With the default `primary_key: true`, it **redefines `created_at`** to be derived from that column instead of from the id.

So:

```ruby
# A required reference:
ulid :learner_id, primary_key: false
belongs_to :learner

# An optional reference: never `ulid`.
attribute :learner_id, ULID::Rails::Type.new
belongs_to :learner, optional: true
```

The model generator template (`lib/templates/active_record/model/model.rb.tt`) still writes plain `ulid :x_id`; fix that by hand.

## Migrations

- `t.references` comes out `NOT NULL` here. For an optional reference write `null: true` explicitly.
- Create tables with `id: :uuid`, and give `t.references` `type: :uuid`.
- After migrating, restart the server (`heighliner up`): the running app keeps the old column list, and a new attribute fails with `unknown attribute 'x'` (the API then answers 400 or 500 with an unhelpful body).
- Migrate both databases: `heighliner login bin/rails db:migrate` and `heighliner login bin/rails db:migrate RAILS_ENV=test`. `db/` is mounted into the container, so `db/schema.rb` is updated on the host.
