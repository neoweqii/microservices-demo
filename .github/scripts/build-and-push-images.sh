#!/usr/bin/env bash

set -euo pipefail

: "${IMAGE_REGISTRY:?IMAGE_REGISTRY is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"

PUSH_LATEST="${PUSH_LATEST:-true}"
INCLUDE_LOADGENERATOR="${INCLUDE_LOADGENERATOR:-false}"

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

for service_definition in "${SERVICES[@]}"; do
  IFS=":" read -r service_name build_context dockerfile_name <<< "${service_definition}"

  image_with_sha="${IMAGE_REGISTRY}/${service_name}:${IMAGE_TAG}"
  image_latest="${IMAGE_REGISTRY}/${service_name}:latest"

  echo "Building ${image_with_sha} from ${build_context}/${dockerfile_name}"
  docker build \
    --file "${build_context}/${dockerfile_name}" \
    --tag "${image_with_sha}" \
    "${build_context}"

  echo "Pushing ${image_with_sha}"
  docker push "${image_with_sha}"

  if [[ "${PUSH_LATEST}" == "true" ]]; then
    echo "Tagging ${image_latest}"
    docker tag "${image_with_sha}" "${image_latest}"

    echo "Pushing ${image_latest}"
    docker push "${image_latest}"
  fi
done
