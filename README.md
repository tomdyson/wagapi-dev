# wagapi-dev

Dev workspace for working on [wagtail-write-api](https://github.com/tomdyson/wagtail-write-api) and [wagapi](https://github.com/tomdyson/wagapi) together.

## Setup

Requires [just](https://github.com/casey/just) and [uv](https://github.com/astral-sh/uv).

```bash
git clone https://github.com/tomdyson/wagapi-dev.git
cd wagapi-dev
just setup    # clones both repos and installs dependencies
just serve    # starts the dev server with test data
just test     # runs both test suites
```

## Commands

| Command           | Description                                      |
|-------------------|--------------------------------------------------|
| `just clone`      | Clone both repos (skips if already present)      |
| `just setup`      | Clone + install deps                             |
| `just serve`      | Start dev server with demo data                  |
| `just test`       | Run both test suites                             |
| `just test-api`   | wagtail-write-api tests only                     |
| `just test-cli`   | wagapi tests only                                |
| `just lint`       | Ruff check + format check                        |
| `just fmt`        | Auto-format                                      |
| `just pull`       | Git pull both repos                              |
| `just status`     | Git status of both repos                         |
| `just integration`| Start server, run wagapi smoke tests, stop server|

## How it works

This repo is a thin wrapper — the two project repos are cloned inside it and gitignored. A shared `justfile` and `.wagapi.toml` (with the local dev URL pre-filled) make it easy to work across both.

See `CLAUDE.md` for detailed architecture and workflow notes.
