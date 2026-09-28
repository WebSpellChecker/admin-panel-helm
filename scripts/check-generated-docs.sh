#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repository_root"

if ! command -v helm-docs >/dev/null 2>&1; then
  echo "error: helm-docs is required" >&2
  exit 1
fi

temporary_directory=$(mktemp -d)
trap 'rm -rf "$temporary_directory"' EXIT

cp -R admin-panel "$temporary_directory/admin-panel"
helm-docs \
  --chart-search-root="$temporary_directory/admin-panel" \
  --template-files=README.md.gotmpl

if ! diff -u admin-panel/README.md "$temporary_directory/admin-panel/README.md"; then
  echo "error: admin-panel/README.md is out of date; run 'make docs'" >&2
  exit 1
fi
