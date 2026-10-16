#!/bin/sh
set -e
alembic upgrade head
exec uvicorn zalpro_api.main:app --host 0.0.0.0 --port "${PORT:-8000}" --workers 1 --proxy-headers --forwarded-allow-ips='*'
