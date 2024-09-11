#!/usr/bin/env bash
#
# Tests if the given KeycloakRealmImports are imported without errors.
# 

shopt -s inherit_errexit
set -Eeu -o pipefail

declare -r NAMESPACE="${NAMESPACE:-}"

declare -r -a KEYCLOAKREALMIMPORT_NAMES=("${@}")

keycloakrealmimport_available() {
    for r in "${KEYCLOAKREALMIMPORT_NAMES[@]}"; do
        echo "# Checking if KeycloakRealmImport '${r}' has errors..."
        if ! oc get keycloakrealmimports "${r}" \
                --namespace="${NAMESPACE}" &>/dev/null; then
            echo "# [ERROR] KeycloakRealmImport '${r}' not found!"
            return 1
        fi

        has_errors="$(
            oc get keycloakrealmimports "${r}" \
                --namespace="${NAMESPACE}" \
                --output=jsonpath='{.status.conditions[?(@.type=="HasErrors")].status}'
        )"
        echo "# KeycloakRealmImport '${r}' condition='HasErrors=${has_errors}'"

        if [[ "${has_errors}" == "True" ]]; then
            return 1
        fi
    done
    return 0
}

test_keycloakrealmimport() {
    if [[ -z "${NAMESPACE}" ]]; then
        echo "Usage: $$ NAMESPACE=namespace $0 <STATEFULSETS>"
        exit 1
    fi

    if [[ ${#KEYCLOAKREALMIMPORT_NAMES[@]} -eq 0 ]]; then
        echo "Usage: $0 <KEYCLOAKREALMIMPORT_NAMES>"
        exit 1
    fi

    for i in {1..10}; do
        keycloakrealmimport_available &&
            return 0

        wait=$((i * 1))
        echo -e "### [${i}/10] Waiting for ${wait} seconds before retrying...\n"
        sleep ${wait}
    done
    return 1
}

if test_keycloakrealmimport; then
    echo "# KeycloakRealmImports are available: '${KEYCLOAKREALMIMPORT_NAMES[*]}'"
    exit 0
else
    echo "# [ERROR] KeycloakRealmImports not available!"
    exit 1
fi
