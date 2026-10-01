#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repository_root"

for required_command in helm kubeconform; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "error: $required_command is required" >&2
    exit 1
  fi
done

chart=./admin-panel
namespace=wsc
kubernetes_version=${KUBERNETES_VERSION:-1.27.0}
# The CRDs catalog has the Gateway API and cert-manager schemas. Without it,
# kubeconform skips those kinds. -ignore-missing-schemas only covers kinds that
# neither location has.
crds_catalog='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
kubeconform_args=(
  -strict
  -summary
  -schema-location default
  -schema-location "$crds_catalog"
  -ignore-missing-schemas
  -kubernetes-version "$kubernetes_version"
)

validate_scenario() {
  local name=$1
  shift

  echo "Validating $name"
  helm lint "$chart" "$@"
  helm template admin-panel "$chart" --namespace "$namespace" "$@" |
    kubeconform "${kubeconform_args[@]}"
}

validate_scenario default -f admin-panel/ci/default-values.yaml
validate_scenario minimal -f docs/examples/values-minimal.yaml
validate_scenario gateway-tls -f docs/examples/values-gateway-tls.yaml
validate_scenario ingress -f docs/examples/values-ingress.yaml
validate_scenario storage \
  -f docs/examples/values-minimal.yaml \
  -f docs/examples/values-storage.yaml
