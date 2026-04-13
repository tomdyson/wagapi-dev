# CLAUDE.md

## Workspace overview

This directory contains three related projects by the same author:

- **wagtail-write-api/** — A read/write REST API plugin for Wagtail CMS, built on Django Ninja. Adds full CRUD for pages and images to Wagtail's read-only API.
- **wagapi/** — A CLI client for wagtail-write-api, optimised for LLM orchestration. Translates CLI commands into HTTP calls and returns structured output.
- **wagtail-mobile/** — An Expo (React Native) mobile app for browsing and quick-editing Wagtail content. Dashboard-style interface with page tree browser, page detail/edit, and image gallery.

wagapi and wagtail-mobile both depend on a running wagtail-write-api instance. The wagtail-write-api example app provides a local dev server with test data and API tokens.

## Quick start (both projects)

```bash
# 1. Start the wagtail-write-api example app
cd wagtail-write-api/example
uv run python manage.py migrate
uv run python manage.py seed_demo    # creates users, pages, prints API tokens
uv run python manage.py runserver

# 2. Configure wagapi to talk to it
export WAGAPI_URL=http://localhost:8000/api/write/v1
export WAGAPI_TOKEN=<admin token from seed_demo output>

# 3. Test the CLI
cd ../../wagapi
wagapi schema
```

## Quick commands (justfile)

```bash
just clone          # git clone all repos (skip if already present)
just setup          # clone + install deps for API and CLI
just setup-mobile   # install mobile app deps (npm install)
just test           # run both test suites
just test-api       # wagtail-write-api tests only
just test-cli       # wagapi tests only
just lint           # ruff check + format check
just fmt            # auto-format
just serve          # migrate, seed, start dev server
just dev-mobile     # start Expo dev server for mobile app
just check-mobile   # TypeScript check for mobile app
just pull           # git pull all repos
just status         # git status of all repos
just integration    # start server, run wagapi smoke tests, stop server
```

## wagtail-write-api

**Key commands:**
```bash
cd wagtail-write-api
uv run pytest                        # run tests
uv run ruff check src/ tests/        # lint
uv run ruff format src/ tests/       # format
```

**Architecture:**
- `src/wagtail_write_api/api.py` — NinjaAPI instance, global exception handlers
- `src/wagtail_write_api/endpoints/pages.py` — Page CRUD, publish/unpublish, copy/move, revisions
- `src/wagtail_write_api/endpoints/images.py` — Image upload and CRUD
- `src/wagtail_write_api/endpoints/schema_discovery.py` — Schema discovery (`/schema/`, `/schema/{type}/`)
- `src/wagtail_write_api/schema/` — Dynamic Pydantic schemas from Wagtail models
- `src/wagtail_write_api/models.py` — ApiToken model (replaces rest_framework.authtoken)
- `src/wagtail_write_api/auth.py` — HttpBearer auth using ApiToken
- `src/wagtail_write_api/converters/rich_text.py` — Markdown/HTML to Wagtail internal format
- `src/wagtail_write_api/management/commands/create_api_token.py` — Token management command
- `example/testapp/models.py` — Test page models used by example app and test suite

**API conventions:**
- All URLs require trailing slashes (e.g. `/pages/`, `/pages/3/`)
- Auth via `Authorization: Bearer <token>`
- `python manage.py create_api_token <username>` to create tokens

**Testing:** pytest-django, fixtures in `tests/conftest.py`. Status 422 for business logic errors, 400 for Django validation errors. Test models in `example/testapp/models.py` include both `RichTextField` (SimplePage) and `StreamField` (BlogPage, EventPage) body fields — test both when changing body/content handling. Read-only test classes use Django `TestCase` with `setUpTestData` (creates the page tree once per class, wraps each test in a savepoint). Write/mutating tests use pytest fixtures. When adding new read-only tests, prefer the `_PageTreeMixin` + `TestCase` pattern from `test_pages_read.py` to keep tests fast.

**Docs:** `docs/` directory, served via GitHub Pages. Update docs when changing API behaviour.

## wagapi

**Key commands:**
```bash
cd wagapi
pip install -e ".[dev]"
pytest tests/ -v
```

**CLI structure:**
```
wagapi
├── init              — configure connection (writes ~/.wagapi.toml)
├── schema [type]     — list page types or show field schema
├── pages
│   ├── list/get/create/update/delete
│   ├── find <query>  — search pages by title/content
│   ├── publish/unpublish
└── images
    ├── list/get
    ├── upload <file>  — upload an image
```

**Key behaviours:**
- `--parent` accepts page ID or URL path (e.g. `/blog/`)
- `pages get` accepts page ID or URL path (e.g. `wagapi pages get /blog/my-post/`)
- `--field` auto-detects StreamField and RichTextField fields via schema. StreamField values are converted from markdown to blocks; RichTextField values are sent as markdown for server-side conversion. Block types are auto-remapped when the target StreamField uses non-standard names (e.g. `text` instead of `paragraph`). Values starting with `[` or `{` are auto-parsed as JSON for full StreamField control.
- Output is JSON when piped, human-readable in TTY
- Config priority: CLI flags > env vars > `./.wagapi.toml` > `~/.wagapi.toml`
- Exit codes: 0=success, 2=usage, 3=network, 4=auth, 5=permission, 6=not found, 7=validation

## wagtail-mobile

**Key commands:**
```bash
cd wagtail-mobile
npm install                          # install deps
npx expo start                       # start Expo dev server
npx tsc --noEmit                     # TypeScript check
```

**Architecture:**
- `app/_layout.tsx` — Root layout with auth gate and AuthContext provider
- `app/login.tsx` — Login screen (username/password → token exchange)
- `app/(tabs)/index.tsx` — Pages tab (tree browser, root-level pages)
- `app/(tabs)/images.tsx` — Images tab (thumbnail grid with search)
- `app/pages/[id].tsx` — Page detail/edit (edit title/slug, publish/unpublish)
- `app/pages/children/[parentId].tsx` — Recursive page children browser
- `app/images/[id].tsx` — Image detail with full-size preview
- `lib/api.ts` — fetch-based API client with typed endpoints
- `lib/types.ts` — TypeScript types mirroring API response shapes
- `lib/auth.ts` — SecureStore read/write for URL + token
- `lib/hooks/useAuth.ts` — AuthContext and useAuth hook
- `lib/hooks/usePages.ts` — Page data fetching hooks
- `lib/hooks/useImages.ts` — Image data fetching hooks
- `components/PageRow.tsx` — Row in tree list (title, type, status, chevron)
- `components/StatusBadge.tsx` — Live/Draft status dot indicator
- `components/ImageCard.tsx` — Thumbnail card for image grid

**Stack:** Expo SDK 54, TypeScript, Expo Router (file-based), expo-secure-store, expo-haptics. No third-party HTTP, state management, or UI component libraries.

**Auth flow:** Username/password login via `POST /auth/token/` endpoint. Token stored in SecureStore. "Disconnect" clears local storage only.

## Working across all repos

- **Always `cd` explicitly before git/test/push commands.** The Bash tool's working directory can drift silently — especially `git push` will push whatever repo you're actually in, not the one you think. Use `cd /home/sprite/wag-api-work/wagtail-write-api && ...` or `cd /home/sprite/wag-api-work/wagapi && ...` rather than relative paths. Put the `cd` in the **same command** as the operation, not in a separate Bash call.
- **Change wagtail-write-api first, then wagapi.** The API defines the contract; the CLI consumes it. Update and test the API side, then update the client to match.
- **The two repos share no venv.** Each has its own `.venv/`. Run wagtail-write-api tests with `cd /home/sprite/wag-api-work/wagtail-write-api && uv run pytest` (which uses its venv and includes dev deps like pytest-django). Run wagapi tests with `cd /home/sprite/wag-api-work/wagapi && python -m pytest tests/`. **Important:** after deleting `.venv/` or a fresh clone, run `uv sync --extra dev` in wagtail-write-api before testing — `uv sync` alone skips test dependencies (pytest, ruff, etc.).
- **wagapi tests are pure mocks (respx), wagtail-write-api tests hit a real DB.** When renaming an API path, you need to update both the mocked URLs in wagapi tests and the real URLs in wagtail-write-api tests.
- **To integration-test wagapi against the real API**, start the example app first (`cd wagtail-write-api/example && uv run python manage.py runserver`), then set `WAGAPI_URL` and `WAGAPI_TOKEN` env vars. The server takes 3-5 seconds to start — add a `sleep` before the first request. wagapi's unit tests don't need a running server.
- **When changing API query parameter names or body formats**, check both sides: the API endpoint signature in `endpoints/pages.py` and the client's param mapping in `wagapi/commands/pages.py`. These can silently diverge — the API ignores unknown query params, so a mismatched name fails silently.

## Releasing

Both repos follow the same pattern: bump version, commit, push, `gh release create`.

**Versioning scheme (0.Y.Z):** The two projects share a minor version to indicate API compatibility. A **minor bump (0.Y.0)** means an API contract change — both repos must release together at the same 0.Y.0. A **patch bump (0.Y.Z)** is for changes that don't affect the API contract (bugfixes, performance, cosmetic CLI changes) and can be released independently per-repo. This scheme started at 0.6.0.

**wagtail-write-api** — version lives in two files:
```
src/wagtail_write_api/__init__.py   →  __version__ = "X.Y.Z"
pyproject.toml                      →  version = "X.Y.Z"
```

**wagapi** — version lives in two files:
```
wagapi/__init__.py                  →  __version__ = "X.Y.Z"
pyproject.toml                      →  version = "X.Y.Z"
```

Both files in each repo must match. After committing and pushing:
```bash
cd /home/sprite/wag-api-work/wagtail-write-api && gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."
cd /home/sprite/wag-api-work/wagapi && gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."
```

CI publishes to PyPI automatically via trusted publishing on both repos.

## CLI output and the Bash tool

wagapi auto-detects TTY vs pipe for output format (JSON when piped, human-readable in TTY). The Bash tool is **not a TTY**, so wagapi will always produce JSON output by default. Use `--human` to force human-readable output when testing interactively via the Bash tool. **Note:** `--human`, `--json`, `--verbose`, and `--dry-run` are global flags that must come before the subcommand: `wagapi --human pages list`, not `wagapi pages list --human`.

## Requirements

- Python 3.10+
- Wagtail 6.0+
