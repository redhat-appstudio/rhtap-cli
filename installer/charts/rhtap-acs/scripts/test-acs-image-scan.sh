#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

export ROX_CENTRAL_ENDPOINT="$(kubectl get secrets -n rhtap rhtap-acs-integration -o jsonpath='{.data.endpoint}' | base64 -d)"
export ROX_API_TOKEN="$(kubectl get secrets -n rhtap rhtap-acs-integration -o jsonpath='{.data.token}' | base64 -d)"

IMAGE="${IMAGE:-quay.io/fedora/fedora:36-x86_64@sha256:d6e4c7d6d1eaa24d71c8efd7432890acdc0179502224d0aaad6bb05d15ffde19}"

echo "# Download roxctl cli from ${ROX_CENTRAL_ENDPOINT}"
curl --insecure -s -L -H "Authorization: Bearer $ROX_API_TOKEN" \
  "https://${ROX_CENTRAL_ENDPOINT}/api/cli/download/roxctl-linux" \
  --output ./roxctl  \
  > /dev/null
if [ $? -ne 0 ]; then
  note='Failed to download roxctl'
  echo $note
  exit 1
fi
chmod +x ./roxctl  > /dev/null
echo

while true; do
  echo "# roxctl image scan"
  date
  if ./roxctl image scan \
      "--insecure-skip-tls-verify" \
      -e "${ROX_CENTRAL_ENDPOINT}" \
      --image "$IMAGE" \
      --output json \
      --force; then
    break
  fi
  echo "Waiting"
  echo
  sleep 60
  echo "Retrying"
done
rm ./roxctl
echo

echo "# Success"
