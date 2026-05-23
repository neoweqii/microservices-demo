#!/usr/bin/env bash

set -euo pipefail

: "${OUTPUT_DIR:?OUTPUT_DIR is required}"
: "${IMAGE_REGISTRY:?IMAGE_REGISTRY is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${K8S_NAMESPACE:?K8S_NAMESPACE is required}"

INCLUDE_LOADGENERATOR="${INCLUDE_LOADGENERATOR:-false}"

mkdir -p "${OUTPUT_DIR}"

loadgenerator_resource=""
loadgenerator_image=""

if [[ "${INCLUDE_LOADGENERATOR}" == "true" ]]; then
  loadgenerator_resource="  - ../../../kubernetes-manifests/loadgenerator.yaml"
  loadgenerator_image=$(cat <<EOF
  - name: loadgenerator
    newName: ${IMAGE_REGISTRY}/loadgenerator
    newTag: ${IMAGE_TAG}
EOF
)
fi

cat > "${OUTPUT_DIR}/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${K8S_NAMESPACE}
resources:
  - ../../../kubernetes-manifests/adservice.yaml
  - ../../../kubernetes-manifests/cartservice.yaml
  - ../../../kubernetes-manifests/checkoutservice.yaml
  - ../../../kubernetes-manifests/currencyservice.yaml
  - ../../../kubernetes-manifests/emailservice.yaml
  - ../../../kubernetes-manifests/frontend.yaml
  - ../../../kubernetes-manifests/paymentservice.yaml
  - ../../../kubernetes-manifests/productcatalogservice.yaml
  - ../../../kubernetes-manifests/recommendationservice.yaml
  - ../../../kubernetes-manifests/shippingservice.yaml
${loadgenerator_resource}
images:
  - name: adservice
    newName: ${IMAGE_REGISTRY}/adservice
    newTag: ${IMAGE_TAG}
  - name: cartservice
    newName: ${IMAGE_REGISTRY}/cartservice
    newTag: ${IMAGE_TAG}
  - name: checkoutservice
    newName: ${IMAGE_REGISTRY}/checkoutservice
    newTag: ${IMAGE_TAG}
  - name: currencyservice
    newName: ${IMAGE_REGISTRY}/currencyservice
    newTag: ${IMAGE_TAG}
  - name: emailservice
    newName: ${IMAGE_REGISTRY}/emailservice
    newTag: ${IMAGE_TAG}
  - name: frontend
    newName: ${IMAGE_REGISTRY}/frontend
    newTag: ${IMAGE_TAG}
  - name: paymentservice
    newName: ${IMAGE_REGISTRY}/paymentservice
    newTag: ${IMAGE_TAG}
  - name: productcatalogservice
    newName: ${IMAGE_REGISTRY}/productcatalogservice
    newTag: ${IMAGE_TAG}
  - name: recommendationservice
    newName: ${IMAGE_REGISTRY}/recommendationservice
    newTag: ${IMAGE_TAG}
  - name: shippingservice
    newName: ${IMAGE_REGISTRY}/shippingservice
    newTag: ${IMAGE_TAG}
${loadgenerator_image}
EOF
