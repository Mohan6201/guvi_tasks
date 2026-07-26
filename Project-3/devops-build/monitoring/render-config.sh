#!/bin/bash
set -e

# docker-compose does NOT substitute ${VAR} placeholders inside files it bind-mounts
# into containers — only inside the compose YAML itself. alertmanager.yml.template
# still needs SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASSWORD/ALERT_EMAIL rendered in
# manually before `docker-compose up`. Uses sed (not envsubst — not guaranteed
# present on a bare Ubuntu box).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${SMTP_HOST:?SMTP_HOST not set — export your .env first}"
: "${SMTP_PORT:?SMTP_PORT not set}"
: "${SMTP_USER:?SMTP_USER not set}"
: "${SMTP_PASSWORD:?SMTP_PASSWORD not set}"
: "${ALERT_EMAIL:?ALERT_EMAIL not set}"

sed \
    -e "s|\${SMTP_HOST}|${SMTP_HOST}|g" \
    -e "s|\${SMTP_PORT}|${SMTP_PORT}|g" \
    -e "s|\${SMTP_USER}|${SMTP_USER}|g" \
    -e "s|\${SMTP_PASSWORD}|${SMTP_PASSWORD}|g" \
    -e "s|\${ALERT_EMAIL}|${ALERT_EMAIL}|g" \
    "${SCRIPT_DIR}/alertmanager.yml.template" > "${SCRIPT_DIR}/alertmanager.yml"

echo "Rendered alertmanager.yml.template -> alertmanager.yml"
