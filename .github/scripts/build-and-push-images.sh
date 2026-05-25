#!/usr/bin/env bash

set -euo pipefail

: "${IMAGE_REGISTRY:?IMAGE_REGISTRY is required}"

PUSH_LATEST="${PUSH_LATEST:-true}"
INCLUDE_LOADGENERATOR="${INCLUDE_LOADGENERATOR:-false}"
IMAGE_TAG_OVERRIDE="${IMAGE_TAG_OVERRIDE:-${IMAGE_TAG:-}}"
IMAGE_TAGS_FILE="${IMAGE_TAGS_FILE:-}"
BUILD_SUMMARY_FILE="${BUILD_SUMMARY_FILE:-}"

SERVICES=(
  "adservice:src/adservice:Dockerfile"
  "cartservice:src/cartservice/src:Dockerfile"
  "checkoutservice:src/checkoutservice:Dockerfile"
  "currencyservice:src/currencyservice:Dockerfile"
  "emailservice:src/emailservice:Dockerfile"
  "frontend:src/frontend:Dockerfile"
  "paymentservice:src/paymentservice:Dockerfile"
  "productcatalogservice:src/productcatalogservice:Dockerfile"
  "recommendationservice:src/recommendationservice:Dockerfile"
  "shippingservice:src/shippingservice:Dockerfile"
)

if [[ "${INCLUDE_LOADGENERATOR}" == "true" ]]; then
  SERVICES+=("loadgenerator:src/loadgenerator:Dockerfile")
fi

export DOCKER_BUILDKIT=1

remote_image_exists() {
  docker pull "$1" >/dev/null 2>&1
}

ensure_tags_file_dir() {
  if [[ -n "${IMAGE_TAGS_FILE}" ]]; then
    mkdir -p "$(dirname "${IMAGE_TAGS_FILE}")"
    : > "${IMAGE_TAGS_FILE}"
  fi
}

ensure_summary_file_dir() {
  if [[ -n "${BUILD_SUMMARY_FILE}" ]]; then
    mkdir -p "$(dirname "${BUILD_SUMMARY_FILE}")"
    : > "${BUILD_SUMMARY_FILE}"
  fi
}

record_service_tag() {
  local service_name="$1"
  local service_tag="$2"

  if [[ -n "${IMAGE_TAGS_FILE}" ]]; then
    printf '%s=%s\n' "${service_name}" "${service_tag}" >> "${IMAGE_TAGS_FILE}"
  fi
}

record_build_summary() {
  local service_name="$1"
  local build_status="$2"
  local service_tag="$3"

  if [[ -n "${BUILD_SUMMARY_FILE}" ]]; then
    printf '%s=%s:%s\n' "${service_name}" "${build_status}" "${service_tag}" >> "${BUILD_SUMMARY_FILE}"
  fi
}

resolve_service_tag() {
  local build_context="$1"

  if [[ -n "${IMAGE_TAG_OVERRIDE}" ]]; then
    printf '%s' "${IMAGE_TAG_OVERRIDE}"
    return
  fi

  # Reuse images across commits when the build context did not change.
  printf 'ctx-%s' "$(git rev-parse "HEAD:${build_context}")"
}

ensure_tags_file_dir
ensure_summary_file_dir

for service_definition in "${SERVICES[@]}"; do
  IFS=":" read -r service_name build_context dockerfile_name <<< "${service_definition}"

  service_tag="$(resolve_service_tag "${build_context}")"
  image_with_sha="${IMAGE_REGISTRY}/${service_name}:${service_tag}"
  image_latest="${IMAGE_REGISTRY}/${service_name}:latest"

  record_service_tag "${service_name}" "${service_tag}"

  if remote_image_exists "${image_with_sha}"; then
    echo "Image ${image_with_sha} already exists in registry"
    record_build_summary "${service_name}" "reused" "${service_tag}"

    if [[ "${PUSH_LATEST}" == "true" ]]; then
      if remote_image_exists "${image_latest}"; then
        echo "Image ${image_latest} already exists in registry, skipping ${service_name}"
        continue
      fi

      echo "Reusing ${image_with_sha} to publish missing ${image_latest}"
      docker tag "${image_with_sha}" "${image_latest}"
      docker push "${image_latest}"
      continue
    fi

    echo "Skipping ${service_name}"
    continue
  fi

  echo "Building ${image_with_sha} from ${build_context}/${dockerfile_name}"
  docker build \
    --file "${build_context}/${dockerfile_name}" \
    --tag "${image_with_sha}" \
    "${build_context}"
  record_build_summary "${service_name}" "rebuilt" "${service_tag}"

  echo "Pushing ${image_with_sha}"
  docker push "${image_with_sha}"

  if [[ "${PUSH_LATEST}" == "true" ]]; then
    echo "Tagging ${image_latest}"
    docker tag "${image_with_sha}" "${image_latest}"

    echo "Pushing ${image_latest}"
    docker push "${image_latest}"
  fi
done
