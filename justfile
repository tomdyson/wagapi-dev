# Run from the workspace root — recipes always cd to the right repo first.

api_dir := justfile_directory() / "wagtail-write-api"
cli_dir := justfile_directory() / "wagapi"
example_dir := api_dir / "example"

# Clone both repos (skip if already present)
clone:
    @if [ ! -d "{{api_dir}}" ]; then git clone https://github.com/tomdyson/wagtail-write-api.git {{api_dir}}; else echo "wagtail-write-api already cloned"; fi
    @if [ ! -d "{{cli_dir}}" ]; then git clone https://github.com/tomdyson/wagapi.git {{cli_dir}}; else echo "wagapi already cloned"; fi

# Install dependencies for both repos
setup: clone
    cd {{api_dir}} && uv sync --extra dev
    cd {{cli_dir}} && pip install -e ".[dev]"

# Run all tests across both repos
test: test-api test-cli

# wagtail-write-api tests
test-api:
    cd {{api_dir}} && uv run pytest

# wagapi tests
test-cli:
    cd {{cli_dir}} && python -m pytest tests/

# Lint + format wagtail-write-api
lint:
    cd {{api_dir}} && uv run ruff check src/ tests/
    cd {{api_dir}} && uv run ruff format --check src/ tests/

# Auto-format wagtail-write-api
fmt:
    cd {{api_dir}} && uv run ruff format src/ tests/

# Start the example dev server (migrate + seed if needed)
serve:
    cd {{example_dir}} && uv run python manage.py migrate --run-syncdb
    cd {{example_dir}} && uv run python manage.py seed_demo
    cd {{example_dir}} && uv run python manage.py runserver

# Pull latest for both repos
pull:
    cd {{api_dir}} && git pull
    cd {{cli_dir}} && git pull

# Show status of both repos
status:
    @echo "=== wagtail-write-api ===" && cd {{api_dir}} && git status --short --branch
    @echo ""
    @echo "=== wagapi ===" && cd {{cli_dir}} && git status --short --branch

# Integration test: start server, run wagapi against it, stop server
integration:
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{example_dir}} && uv run python manage.py migrate --run-syncdb
    TOKEN=$(cd {{example_dir}} && uv run python manage.py seed_demo 2>&1 | grep -oP 'Admin token: \K\S+')
    cd {{example_dir}} && uv run python manage.py runserver &
    SERVER_PID=$!
    trap "kill $SERVER_PID 2>/dev/null" EXIT
    sleep 3
    export WAGAPI_URL=http://localhost:8000/api/write/v1
    export WAGAPI_TOKEN="$TOKEN"
    cd {{cli_dir}}
    echo "=== Schema ===" && wagapi schema
    echo "=== Pages ===" && wagapi pages list
    echo "=== Images ===" && wagapi images list
    echo ""
    echo "Integration tests passed."
