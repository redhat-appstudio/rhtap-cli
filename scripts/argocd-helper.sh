#!/usr/bin/env bash
#
# Tests if the ArgoCD instance is available on the cluster by logging in.
#
# Uses the ArgoCD session, created by previously running "argocd login", to
# generate an acccount token. The informaton is then stored in the ARGOCD_ENV_FILE
# variable.
#

shopt -s inherit_errexit
set -Eeu -o pipefail

declare -r SUBCOMMAND="${1:-}"

# ArgoCD hostname (FQDN) to test.
declare -r ARGOCD_HOSTNAME="${ARGOCD_HOSTNAME:-}"
# ArgoCD username to use for login.
declare -r ARGOCD_USER="${ARGOCD_USER:-admin}"
# ArgoCD password to use for login.
declare -r ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-}"
# Environment file to store the ArgoCD credentials.
declare -r ARGOCD_ENV_FILE="${ARGOCD_ENV_FILE:-/rhtap/argocd/env}"

fail() {
    echo "# [ERROR] ${*}" >&2
    exit 1
}

# Asserts the required environment variables.
assert_variables() {
    [[ -z "${ARGOCD_HOSTNAME}" ]] &&
        fail "ARGOCD_HOSTNAME is not set!"
    [[ -z "${ARGOCD_USER}" ]] &&
        fail "ARGOCD_USER is not set!"
    [[ -z "${ARGOCD_PASSWORD}" ]] &&
        fail "ARGOCD_PASSWORD is not set!"
}

# Executes the ArgoCD login command.
argocd_login() {
    argocd login "${ARGOCD_HOSTNAME}" \
        --grpc-web \
        --insecure \
        --http-retry-max="5" \
        --username="${ARGOCD_USER}" \
        --password="${ARGOCD_PASSWORD}"
}

# Retries a few times until the ArgoCD instance is available.
test_argocd_login() {
    for i in {1..30}; do
        echo "# [${i}/30] Testing ArgoCD login on '${ARGOCD_HOSTNAME}'..."
        argocd_login &&
            return 0

        wait=$((i * 5))
        echo "### [${i}/30] Waiting for ${wait} seconds before retrying..."
        sleep ${wait}
    done
    return 1
}

# Generates the ArgoCD API token.
argocd_generate_token() {
    echo "# Generating ArgoCD API token on '${ARGOCD_HOSTNAME}'..."
    ARGOCD_API_TOKEN="$(
        argocd account generate-token \
            --grpc-web \
            --insecure \
            --http-retry-max="5" \
            --account="${ARGOCD_USER}"
    )" || fail "ArgoCD API token could not be generated!"
    if [[ "${?}" -ne 0 || -z "${ARGOCD_API_TOKEN}" ]]; then
        fail "ArgoCD API token could not be generated!"
    fi

    echo "# Storing ArgoCD API credentials on '${ARGOCD_ENV_FILE}'..."
    cat <<EOF >"${ARGOCD_ENV_FILE}" || fail "Fail to write '${ARGOCD_ENV_FILE}'!"
ARGOCD_HOSTNAME="${ARGOCD_HOSTNAME}"
ARGOCD_USER="${ARGOCD_USER}"
ARGOCD_PASSWORD="${ARGOCD_PASSWORD}"
ARGOCD_API_TOKEN="${ARGOCD_API_TOKEN}"
EOF
    return 0
}

#
# Main
#

assert_variables &&
    echo "# All environment variables are set"

case "${SUBCOMMAND}" in
login)
    if test_argocd_login; then
        echo "# ArgoCD is available: '${ARGOCD_HOSTNAME}'"
        exit 0
    else
        fail "ArgoCD not available!"
    fi
    ;;
generate)
    echo "# Logging into ArgoCD on '${ARGOCD_HOSTNAME}'..."
    test_argocd_login ||
        fail "ArgoCD not available!"

    if argocd_generate_token; then
        echo "# ArgoCD API token generated successfully!"
        cat "${ARGOCD_ENV_FILE}"
        exit 0
    else
        fail "ArgoCD API token could not be generated!"
    fi
    ;;
*)
    fail "Invalid subcommand provided: '${SUBCOMMAND}'. " \
        "Use 'login' or 'generate'!"
    ;;
esac
