#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Number of retries to attempt before giving up.
declare -r RETRIES=${RETRIES:-30}

get_roxctl() {
  echo "# Download roxctl cli from ${ROX_CENTRAL_ENDPOINT}"
  curl --fail --insecure -s -L -H "Authorization: Bearer $ROX_API_TOKEN" \
    "https://${ROX_CENTRAL_ENDPOINT}/api/cli/download/roxctl-linux" \
    --output ./roxctl  \
    > /dev/null || {
      echo '[ERROR] Failed to download roxctl'
      exit 1
    }
  chmod +x ./roxctl > /dev/null
}

test_scanner() {
  for i in $(seq 1 "${RETRIES}"); do
    wait=30
    echo
    date
    echo "### [${i}/${RETRIES}] roxctl image scan"
    if ./roxctl image scan \
        "--insecure-skip-tls-verify" \
        -e "${ROX_CENTRAL_ENDPOINT}" \
        --image "$IMAGE" \
        --output json \
        --force; then
      break
    fi
    if [ "$i" -eq "${RETRIES}" ]; then
      echo
      echo '[ERROR] Failed to test ACS scanner'
      exit 1
    fi
    echo "# Waiting for ${wait} seconds before retrying..."
    sleep ${wait}
  done
}

get_roxctl
test_scanner
echo
echo "# Success"
