#!/usr/bin/env bash
#
# Tests if the requested CRDs are available on the cluster.
#

shopt -s inherit_errexit
set -Eeu -o pipefail

# List of CRDs to test.
declare -r -a CRDS=("${@}")

# Tests if the CRDs are available on the cluster, returns true when all CRDs are
# found, otherwise false.
api_resources_available() {
    SUCCESS=0
    for crd in "${CRDS[@]}"; do
        echo "# Checking if CRD '${crd}' is present on the cluster..."
        if (! oc get customresourcedefinitions "${crd}"); then
            echo -e "# ERROR: CRD '${crd}' not found."
            SUCCESS=1
        else
            echo "# CRD '${crd}' is installed."
        fi
    done
    return "$SUCCESS"
}

# Verifies the availability of the CRDs, retrying a few times.
test_subscriptions() {
    if [[ ${#CRDS[@]} -eq 0 ]]; then
        echo "Usage: $0 <CRDS>"
        exit 1
    fi

    for i in {1..20}; do
        api_resources_available &&
            return 0

        wait=$((i * 3))
        echo "### [${i}/20] Waiting for ${wait} seconds before retrying..."
        sleep ${wait}
    done
    return 1
}

#
# Main
#

if test_subscriptions; then
    echo "# CRDs are available: '${CRDS[*]}'"
    exit 0
else
    echo "# ERROR: CRDs not available!"
    exit 1
fi
