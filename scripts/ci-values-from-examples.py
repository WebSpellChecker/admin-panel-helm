#!/usr/bin/env python3
"""Generate chart-testing values files from the documentation examples.

ct reads scenario files from admin-panel/ci/*-values.yaml. The examples in
docs/examples stay the single source: this script copies each complete example,
and merges the storage overlay onto the minimal example because the overlay is
not a complete values file. The generated files are git-ignored and excluded
from the packaged chart by admin-panel/.helmignore.
"""
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
EXAMPLES = ROOT / "docs" / "examples"
CI_DIR = ROOT / "admin-panel" / "ci"

# ci file name -> example files, merged in order (later files override earlier ones)
SCENARIOS = {
    "example-minimal-values.yaml": ["values-minimal.yaml"],
    "example-gateway-tls-values.yaml": ["values-gateway-tls.yaml"],
    "example-ingress-values.yaml": ["values-ingress.yaml"],
    "example-storage-values.yaml": ["values-minimal.yaml", "values-storage.yaml"],
}


def merge(base, overlay):
    """Merge maps recursively, like Helm does with several --values files."""
    result = dict(base)
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = value
    return result


def main():
    CI_DIR.mkdir(exist_ok=True)
    for target, sources in SCENARIOS.items():
        values = {}
        for source in sources:
            values = merge(values, yaml.safe_load((EXAMPLES / source).read_text()) or {})
        header = f"# Generated from docs/examples/{' + '.join(sources)}. Do not edit.\n"
        (CI_DIR / target).write_text(header + yaml.safe_dump(values, sort_keys=False))
        print(f"wrote admin-panel/ci/{target}")


if __name__ == "__main__":
    main()
