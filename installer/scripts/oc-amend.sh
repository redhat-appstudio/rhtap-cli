#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

# Subcommand to be used in combination with "oc" (or "kubectl").
declare -r SUBCOMMAND="${1:-}"
# Remove the first argument from the list.
shift
# Store the remaining arguments in an array, they represent the final arguments
# to be passed to the "oc" command and subcommand.
declare -r ARGS=("${@}")

# Kubernetes kind to be used in the "oc" command.
declare -r KIND="${KIND:-}"
# Kubernetes namespace.
declare -r NAMESPACE="${NAMESPACE:-}"
# Kubernetes resource name.
declare -r RESOURCE_NAME="${RESOURCE_NAME:-}"

fail() {
    echo "# [ERROR] ${*}" >&2
    exit 1
}

warn() {
    echo "# [WARN] ${*}" >&2
}

# Asserting that the required variables are set.
assert_variables() {
    [[ -z "${KIND}" ]] &&
        fail "KIND is not set!"
    [[ -z "${NAMESPACE}" ]] &&
        warn "NAMESPACE is not set!"
    [[ -z "${RESOURCE_NAME}" ]] &&
        fail "RESOURCE_NAME is not set!"
}

# Amends a Kubernetes resource using the "oc" command.
oc_amend() {
    echo "# Trying to '${SUBCOMMAND}' the resource '${KIND}/${RESOURCE_NAME}' " \
        "with '${ARGS[*]}'..."
    set -x
    oc "${SUBCOMMAND}" "${KIND}" "${RESOURCE_NAME}" \
        --namespace="${NAMESPACE}" \
        "${ARGS[@]}"
    local ret_code=${?}
    set +x
    return ${ret_code}
}

# Retries the "oc_amend" function up to 30 times.
retry_oc_amend() {
    echo "# Kubernetes namespace: '${NAMESPACE}'"
    for i in {1..30}; do
        wait=$((i * 5))
        echo "### [${i}/30] Waiting for ${wait} seconds before retrying..."
        sleep ${wait}

        oc_amend &&
            return 0
    done
    return 1
}

#
# Main
#

if retry_oc_amend; then
    echo "# [INFO] Successfully amended Kubernetes resource."
else
    fail "Failed to amend Kubernetes resource!"
fi
