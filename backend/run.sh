#!/bin/bash
set -euo pipefail

source .venv/bin/activate

# Set ALLOWED_ORIGINS to a comma-separated list of allowed origins for production.
# Example: export ALLOWED_ORIGINS="https://yourdomain.com,https://app.yourdomain.com"
# Leave unset or set to "*" to allow all origins (dev only).

uvicorn main:app \
    --host 0.0.0.0 \
    --port 8000 \
    --no-access-log
