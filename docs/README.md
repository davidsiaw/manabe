# Backend docs

Notes for whoever works on this repository next, human or agent. Read [system.md](system.md) first: it explains what Manabase is, how this repo and the frontend fit together, and the decisions behind them. Then read the file for your task.

| File | Read it when |
|---|---|
| [system.md](system.md) | You are new here. The whole system, its words, and its decisions. Shared with the frontend. |
| [architecture.md](architecture.md) | You are changing code. How the app is laid out, its conventions, and what came from the rails-zen template. |
| [api.md](api.md) | You are adding or calling an endpoint. Every endpoint, with requests, responses and errors. |
| [data-model.md](data-model.md) | You are touching the database: tables, ULIDs, and the ulid-rails traps. |
| [courses.md](courses.md) | You are writing a course, or changing how courses are loaded. |
| [accounts.md](accounts.md) | You are working on learners, sessions, registration, login or passkeys. |
| [progress.md](progress.md) | You are working on progress, rounds, revisions or shuffling. |
| [development.md](development.md) | You are running the app, migrating, or working from the pi sandbox. |
| [deployment.md](deployment.md) | You are deploying to production: the CI pipeline, its secrets, and the server setup. |
| [testing.md](testing.md) | You are writing or running specs. |
| [roadmap.md](roadmap.md) | You want to know what is not built yet, and what is known to be broken. |

Every gotcha recorded here was hit for real at least once. If you hit a new one, add it.
