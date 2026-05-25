#!/usr/bin/env bash

set -euo pipefail

: "${OUTPUT_DIR:?OUTPUT_DIR is required}"
: "${IMAGE_REGISTRY:?IMAGE_REGISTRY is required}"
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"

INCLUDE_LOADGENERATOR="${INCLUDE_LOADGENERATOR:-false}"
MANIFESTS_DIR="${MANIFESTS_DIR:-kubernetes-manifests}"
IMAGE_TAG_OVERRIDE="${IMAGE_TAG_OVERRIDE:-${IMAGE_TAG:-}}"
IMAGE_TAGS_FILE="${IMAGE_TAGS_FILE:-}"

MANIFEST_FILES=(
  "adservice.yaml"
  "cartservice.yaml"
  "checkoutservice.yaml"
  "currencyservice.yaml"
  "emailservice.yaml"
  "frontend.yaml"
  "paymentservice.yaml"
  "productcatalogservice.yaml"
  "recommendationservice.yaml"
  "shippingservice.yaml"
)

declare -A IMAGE_TAGS=()

load_image_tags() {
  if [[ -z "${IMAGE_TAGS_FILE}" || ! -f "${IMAGE_TAGS_FILE}" ]]; then
    return
  fi

  while IFS='=' read -r service_name service_tag; do
    if [[ -n "${service_name}" && -n "${service_tag}" ]]; then
      IMAGE_TAGS["${service_name}"]="${service_tag}"
    fi
  done < "${IMAGE_TAGS_FILE}"
}

resolve_image_tag() {
  local service_name="$1"

  if [[ -n "${IMAGE_TAGS[${service_name}]:-}" ]]; then
    printf '%s' "${IMAGE_TAGS[${service_name}]}"
    return
  fi

  if [[ -n "${IMAGE_TAG_OVERRIDE}" ]]; then
    printf '%s' "${IMAGE_TAG_OVERRIDE}"
    return
  fi

  echo "No image tag found for service ${service_name}" >&2
  exit 1
}

append_image_entry() {
  local service_name="$1"
  local service_tag

  service_tag="$(resolve_image_tag "${service_name}")"
  cat <<EOF
  - name: ${service_name}
    newName: ${IMAGE_REGISTRY}/${service_name}
    newTag: ${service_tag}
EOF
}

mkdir -p "${OUTPUT_DIR}"
load_image_tags

loadgenerator_resource=""
loadgenerator_image=""

if [[ "${INCLUDE_LOADGENERATOR}" == "true" ]]; then
  MANIFEST_FILES+=("loadgenerator.yaml")
  loadgenerator_resource="  - loadgenerator.yaml"
  loadgenerator_image="$(append_image_entry "loadgenerator")"
fi

for manifest_file in "${MANIFEST_FILES[@]}"; do
  cp "${MANIFESTS_DIR}/${manifest_file}" "${OUTPUT_DIR}/${manifest_file}"
done

{
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${K8S_NAMESPACE}
resources:
  - adservice.yaml
  - cartservice.yaml
  - checkoutservice.yaml
  - currencyservice.yaml
  - emailservice.yaml
  - frontend.yaml
  - paymentservice.yaml
  - productcatalogservice.yaml
  - recommendationservice.yaml
  - shippingservice.yaml
${loadgenerator_resource}
images:
EOF
append_image_entry "adservice"
append_image_entry "cartservice"
append_image_entry "checkoutservice"
append_image_entry "currencyservice"
append_image_entry "emailservice"
append_image_entry "frontend"
append_image_entry "paymentservice"
append_image_entry "productcatalogservice"
append_image_entry "recommendationservice"
append_image_entry "shippingservice"

if [[ -n "${loadgenerator_image}" ]]; then
  printf '%s\n' "${loadgenerator_image}"
fi
} > "${OUTPUT_DIR}/kustomization.yaml"
