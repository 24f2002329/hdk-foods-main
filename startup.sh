#!/bin/bash
set -e

cd backend

echo "==> Running migrations..."
python manage.py migrate --noinput

echo "==> Collecting static files..."
python manage.py collectstatic --noinput

echo "==> Starting daphne (ASGI)..."
daphne -b 0.0.0.0 -p 8000 \
  --access-log - \
  config.asgi:application
