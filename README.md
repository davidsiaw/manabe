# Manabase backend

The API behind Manabase, a vibe-coded base system for interactive learning modules: courses written as YAML, multiple choice and code problems (code runs in the learner's browser, or on their own computer, and the backend checks what it printed), anonymous learners who can register with a passkey, and progress tracking with revision rounds. The student-facing app is the frontend repository, normally checked out next to this one.

Built on Rails 8 and Grape, with PostgreSQL, and started from the [rails-zen](https://github.com/davidsiaw/rails-zen) template.

## Running it

```sh
heighliner init manabe     # once
heighliner up -av
curl https://manabe.$(heighliner show http-suffix)/api/v1/health
```

## Writing a course

Add a directory to `courses/`; the format is in [courses/README.md](courses/README.md).

## Documentation

Everything else (how the system fits together, the API, the data model, accounts and passkeys, progress and revisions, development and testing) is in [docs/](docs/README.md). Start with [docs/system.md](docs/system.md).
