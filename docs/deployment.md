# Deployment

A push to the `production` branch (or running the workflow by hand) runs `.github/workflows/deploy.yml`, which builds `Dockerfile` and pushes it to Docker Hub as `davidsiaw/manabe:latest`.

CI does not touch the server. Portainer sits behind Pomerium, which GitHub's runners cannot get through, so the server pulls the new image itself and redeploys the stack from `stack-definition.yml`.

The stack contains Postgres 16, Redis, a one-off `migrate` (`db:prepare`: on the first deploy it creates the database, loads the schema and seeds the admin; after that it migrates), the API (Falcon), and Sidekiq. The API publishes no port. nginx-proxy routes `API_HOST` to it and acme-companion gets its certificate.

## GitHub: secrets (Settings > Secrets and variables > Actions)

Only what CI needs to push the image. The app's own secrets never go to GitHub.

| Secret | What |
|---|---|
| `DOCKER_PASSWORD` | Docker Hub access token for `davidsiaw` |

## Portainer: the stack's environment variables

The `${VAR}`s in `stack-definition.yml` come from the stack's environment variables in Portainer. **Create the stack by hand once**: Stacks > Add stack, use `stack-definition.yml`, add the variables below, and name it (e.g. `manabe`). It will fail to deploy until the image has been pushed once; running the workflow fixes that.

| Variable | What |
|---|---|
| `SECRET_KEY_BASE` | `openssl rand -hex 64` |
| `POSTGRES_PASSWORD` | `openssl rand -hex 32`. Hex only, because it goes into `DATABASE_URL`. Fixed once the database exists; changing it later means `ALTER USER` in Postgres too. |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | admin for `/admins/sign_in` (`/sidekiq`, `/swagger`); used by the first deploy only |
| `API_HOST` | the API's hostname, no scheme, e.g. `api.manabe.example.com`. DNS must point at the server. |
| `FRONTEND_HOSTS` | frontend origins, `https://host`, comma separated, no trailing slash. Used for CORS and, by default, for passkeys. |
| `WEBAUTHN_ORIGINS` | optional; passkey origins if different from `FRONTEND_HOSTS` |
| `WEBAUTHN_RP_ID` | optional; passkey domain. Defaults to the host of the first origin. With frontends on sibling subdomains, set their parent. Changing it orphans every passkey. |

The required ones are written `${VAR:?}`, so a missing one fails the deploy instead of starting the app with an empty value. A variable changed in Portainer takes effect on the next deploy, or on "Update the stack" in Portainer.

## The server, once

- Docker and Portainer (2.x, using docker compose v2, which `depends_on: condition: service_completed_successfully` needs), set up to pull `davidsiaw/manabe:latest` and redeploy the stack when it changes.
- [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy) and [acme-companion](https://github.com/nginx-proxy/acme-companion) on ports 80/443. Skip this if the server already runs them for other stacks.
- The external network and volume the stack expects, with nginx-proxy attached to the network:

  ```sh
  docker network create manabase
  docker network connect manabase nginx-proxy   # use your proxy container's name
  docker volume create manabase-db
  ```

- Ports 80 and 443 open to the internet, so Let's Encrypt can validate.

## Frontends

Build them with `API_BASE_URL=https://<API_HOST>/api/v1` (frontend docs/deployment.md) and serve them over HTTPS from the origins in `FRONTEND_HOSTS`.

## Day to day

- Deploy: push to `production`, or run the workflow from the Actions tab, then let the server pull the image (or "Update the stack" with re-pull in Portainer).
- Logs, `rails console`, and so on: from Portainer's container view, or `docker exec -it <stack>-api-1 bin/rails c` on the server.
- Back up `manabase-db`: `docker exec <stack>-db-1 pg_dump -U manabase manabase_production > backup.sql`.
