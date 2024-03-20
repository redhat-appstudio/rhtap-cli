#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

declare -r NAMESPACE="${NAMESPACE:-}"
declare -r -a STATEFULSETS=("${@}")

rollout_status() {
    oc rollout status statefulset "${1}" \
        --namespace="${NAMESPACE}" \
        --watch \
        --timeout=30s
}

wait_for_statefulset() {
    for s in "${STATEFULSETS[@]}"; do
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
        echo "Usage: $$ NAMESPACE=namespace $0 <STATEFULSETS>"
        exit 1
    fi

    if [[ ${#STATEFULSETS[@]} -eq 0 ]]; then
        echo "Usage: $$ NAMESPACE=namespace $0 <STATEFULSETS>"
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
    echo "# StatefulSets are ready: '${STATEFULSETS[*]}'"
    exit 0
else
    echo "# ERROR: StatefulSets not ready!"
    exit 1
fi
