#!/usr/bin/env bash

declare -r CATALOG_NAME="${1:-}"

if [[ -z "${CATALOG_NAME}" ]]; then
    echo "# Usage: $$ $0 <catalog-name>"
    exit 1
fi

if ! oc get packagemanifests "${CATALOG_NAME}" >/dev/null; then
    echo "# ERROR: No subscription found for '${CATALOG_NAME}'!"
    exit 1
fi

source=$(oc get packagemanifests "${CATALOG_NAME}" \
    --output="jsonpath={.status.catalogSource}")
namespace=$(oc get packagemanifests "${CATALOG_NAME}" \
    --output="jsonpath={.status.catalogSourceNamespace}")

mapfile -t channels < <(echo -en "$(oc get packagemanifests "${CATALOG_NAME}" \
    --output jsonpath='{range .status.channels[*]}{.name}\n{end}')")
mapfile -t startingCSVs < <(echo -en "$(oc get packagemanifests "${CATALOG_NAME}" \
    --output jsonpath='{range .status.channels[*]}{.currentCSV}\n{end}')")

cat <<EOS
       Name: "${CATALOG_NAME}"
     Source: "${source}"
  Namespace: "${namespace}"
    Channel: "${channels[*]}"
StartingCSV: "${startingCSVs[*]}"
EOS
