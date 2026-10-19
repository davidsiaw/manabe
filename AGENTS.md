# Manabase backend: notes for agents

Read [docs/README.md](docs/README.md) before changing anything, and [docs/system.md](docs/system.md) if you are new here. The frontend is in `../frontend`, with its own `docs/`.

The things most likely to bite:

- Run the app with heighliner (`heighliner up -av`), not docker compose. `heighliner down` deletes the development database. See docs/development.md.
- After a migration, migrate the test database too and restart the server with `heighliner up`.
- ULID references: `ulid :x_id, primary_key: false` when required; `attribute :x_id, ULID::Rails::Type.new` when optional. See docs/data-model.md.
- `let(:json)` is memoized; do not use it in examples that make several requests.
- Correct answers must never be sent to the frontend.
- Specs and RuboCop must pass: `heighliner login bundle exec rspec` and `heighliner login bundle exec rubocop`.

## Ruby version

Minimum Ruby 3.4, enforced by `ruby '>= 3.4'` in the Gemfile. Ruby < 3.3.7 has a Mutex/ConditionVariable bug ([ruby-lang #20907](https://bugs.ruby-lang.org/issues/20907)) that makes Async raise `Attempt to unlock a mutex which is not locked` on Falcon/Capybara teardown. Do not work around it in application or gem code; use a supported Ruby.

## Without heighliner

`bin/setuplocal` installs PostgreSQL and Redis in a fresh container, bundles, and sets up both databases. Then `source tmp/localenv.sh` and `bin/rails server -u falcon -p 3000`.
