#!/bin/bash
# ============================================================
# Renders k8s/namespace.yaml, k8s/deployment.yaml, k8s/service.yaml
# (which contain ${VAR} placeholders) into k8s/rendered/*.yaml with
# real values substituted in - sourced from .env, plus any KEY=VALUE
# overrides passed as arguments (e.g. IMAGE_URI=<account>.dkr.ecr...).
#
# Usage:
#   ./render.sh IMAGE_URI=123456789012.dkr.ecr.us-east-1.amazonaws.com/brain-tasks-app:abc123
#
# Uses plain bash + sed (no envsubst/gettext dependency) so it runs
# identically on local Git Bash and inside CodeBuild.
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

for kv in "$@"; do
  export "${kv?}"
done

mkdir -p "$SCRIPT_DIR/rendered"

for tmpl in "$SCRIPT_DIR/namespace.yaml" "$SCRIPT_DIR/deployment.yaml" "$SCRIPT_DIR/service.yaml"; do
  out="$SCRIPT_DIR/rendered/$(basename "$tmpl")"
  content="$(cat "$tmpl")"
  for var in $(grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' "$tmpl" | sed -E 's/\$\{|\}//g' | sort -u); do
    value="${!var}"
    if [ -z "$value" ]; then
      echo "WARNING: \$$var has no value (used in $(basename "$tmpl"))" >&2
    fi
    content="${content//\$\{$var\}/$value}"
  done
  printf '%s\n' "$content" > "$out"
  echo "Rendered $out"
done
