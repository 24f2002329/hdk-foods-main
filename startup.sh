#!/usr/bin/env bash
set -euo pipefail

# Azure App Service may deploy either the full monorepo or only the Django
# backend folder. Start Gunicorn from whichever layout is present so startup
# does not fail with "can't chdir to 'backend'".
APP_ROOT="${APP_PATH:-/home/site/wwwroot}"
cd "$APP_ROOT"

if [ -f "backend/manage.py" ] && [ -d "backend/config" ]; then
  cd backend
elif [ -f "manage.py" ] && [ -d "config" ]; then
  :
else
  echo "Unable to find Django backend. Expected either '$APP_ROOT/backend/manage.py' or '$APP_ROOT/manage.py'." >&2
  echo "Current directory: $(pwd)" >&2
  echo "Top-level files:" >&2
  find . -maxdepth 2 -type f | sed 's#^./#  #' | sort | head -80 >&2
  exit 1
fi

exec gunicorn config.wsgi --bind "0.0.0.0:${PORT:-8000}"
