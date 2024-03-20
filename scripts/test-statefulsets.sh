#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

declare -r NAMESPACE="${NAMESPACE:-}"
declare -r -a STATEFULSETS_SELECTORS=("${@}")

rollout_status() {
    oc rollout status statefulset \
        --namespace="${NAMESPACE}" \
        --watch \
        --timeout=10s \
        --selector="${1}"
}

wait_for_statefulset() {
    for s in "${STATEFULSETS_SELECTORS[@]}"; do
        echo "# Checking if StatefulSet '${s}' is ready..."
        if ! rollout_status "${s}"; then
            echo -en "#\n# WARNING: StatefulSet '${s}' is not ready!\n#\n"
            return 1
        fi
        echo "# StatefulSet '${s}' is ready!"
    done
    return 0
}

test_infrastructure() {
    if [[ -z "${NAMESPACE}" ]]; then
        echo "Usage: \$ NAMESPACE=namespace $0 <STATEFULSETS_SELECTORS>"
        exit 1
    fi

    if [[ ${#STATEFULSETS_SELECTORS[@]} -eq 0 ]]; then
        echo "Usage: \$ NAMESPACE=namespace $0 <STATEFULSETS_SELECTORS>"
        exit 1
    fi

    for i in {1..5}; do
        wait_for_statefulset &&
            return 0

        wait=$((i * 30))
        echo "### [${i}/5] Waiting for ${wait} seconds before retrying..."
        sleep ${wait}
    done

    echo "# ERROR: StatefulSets are not ready!"
    return 1
}

if test_infrastructure; then
    echo "# StatefulSets are ready: '${STATEFULSETS_SELECTORS[*]}'"
    exit 0
else
    echo "# ERROR: StatefulSets not ready!"
    exit 1
fi
