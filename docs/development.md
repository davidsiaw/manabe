# Development

## Running it with heighliner

The app runs in containers managed by [heighliner](https://davidsiaw.github.io/heighliner) (formerly kaiser), configured in `Heighliner.config`: the app (Falcon on port 3000), PostgreSQL 16, and Redis. The environment is called `manabe`.

```sh
heighliner up -av      # build the image and start everything, with the source folders mounted
heighliner logs        # follows the log; never returns, so wrap it: timeout 15 heighliner logs
heighliner login bin/rails db:migrate
heighliner login bundle exec rspec
```

- `-a` mounts `app`, `config`, `courses`, `db`, `lib` and `spec` into the container (the `attach_mount` lines), so edits there are live. Anything else (`Gemfile`, `Dockerfile`, root files) needs `heighliner up` to rebuild. `tmp` and `log` are deliberately not mounted.
- A new top-level folder the app needs must be added to the `Dockerfile` (`ADD`), to `.dockerignore` (an allow-list: `!folder`), and as an `attach_mount`. `courses/` is the example.
- `heighliner up` does not need a `down` first. **`heighliner down` deletes the development database** by design.
- The database's default state comes from `bin/dbsetup` (`db_reset_command`). `heighliner db_reset` restores it, `db_save NAME` and `db_load NAME` snapshot and restore. See the warning about `db_save` below.

## Configuration

Production is configured differently: see [deployment.md](deployment.md).

| Variable | Used for | In Heighliner.config |
|---|---|---|
| `DATABASE_URL` | PostgreSQL | `postgres://postgres:postgres@manabe-db` |
| `REDIS_URL` | Sidekiq, Action Cable | `redis://manabe-redis:6379/0` |
| `WEBAUTHN_ORIGINS`, `WEBAUTHN_RP_ID` | passkeys (accounts.md) | the origins `https://manafe.<suffix>` and `https://manamo.<suffix>`; the RP id `<suffix>` |
| `FRONTEND_HOSTS` | CORS allowed origins, comma separated (`FRONTEND_HOST` still read) | unset, so any origin |
| `CHROME_HOSTNAME`, `TEST_HOST` | browser specs (testing.md) | the shared chrome container, by the name heighliner gives it (`<%= @config[:shared_names][:chrome] %>`: `heighliner-chrome`, or `kaiser-chrome` on hosts upgraded from kaiser), and `manabe-app` |

The names `manabe`, `manafe` and `manamo` (the mobile frontend, `../mobile`) are written into the projects' Heighliner.config files. Renaming an environment means editing them all.

The databases are `manabase_development` and `manabase_test` (`config/database.yml`). They were called `rails_zen_*` before the rename; the dev databases were renamed in place with `ALTER DATABASE`.

## After a migration, restart

The running server keeps the old column list. After `db:migrate`, run `heighliner up`, or every write to the changed table fails with `unknown attribute`. Migrate the test database too.

## From the pi sandbox

The sandbox has no docker socket; the `heighliner` command is forwarded to a spice server that has one. Things specific to working from there:

- `heighliner init`, `deinit`, `shutdown` and `set` are reserved for the user.
- `heighliner login` and `heighliner root` parse options themselves: `heighliner login pg_dump --no-owner ...` fails with `unknown argument`, and so does `sh -c`. Put the commands in a script in a mounted folder (for example `db/`) and run `heighliner login sh /srv/db/script.sh`. Remove the script afterwards.
- Run long commands in the background and watch the output: `(nohup heighliner up -av > /tmp/up.log 2>&1 &)`, then poll the log for `application starting` or `exited with code`.
- `pkill -f 'heighliner up'` also matches the shell running it and kills it. Do not.
- The app is at `https://manabe.<suffix>`, reachable from the sandbox. Service containers (`manabe-db`, `manabe-redis`) are not resolvable from the sandbox, only from the app container.

## Known problems

- **`heighliner db_save` fails** with `Permission denied` writing `~/.heighliner/databases/manabe/master/*.tar.bz` on the host. Worse, it **stops the database container first** and leaves it stopped, so the app loses its database until `heighliner up`. Until the host permissions are fixed, back up with `pg_dump` from the app container (`apk add postgresql-client` as root first) into a mounted folder.
- **`manabe-redis` does not resolve** inside the app container, although heighliner reports starting it. Everything Manabase uses works without Redis, but the Sidekiq dashboard and the browser spec for it fail (testing.md).
- `heighliner up` sometimes fails with `exited with code 125` when replacing a running container; running it again has always worked.
