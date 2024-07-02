#!/usr/bin/env bash
#
# Generates a StackRox API token and stores it on a Kubernetes secret.
#
#   https://access.redhat.com/solutions/5907651
#

shopt -s inherit_errexit
set -Eeu -o pipefail

# StackRox API username.
declare -r ROX_USERNAME="${ROX_USERNAME:-admin}"
# StackRox API password.
declare -r ROX_PASSWORD="${ROX_PASSWORD:-}"
# StackRox API base endpoint.
declare -r ROX_ENDPOINT="${ROX_ENDPOINT:-}"
# StackRox API endpoint path to generate a token.
declare -r ROX_ENDPOINT_PATH="${ROX_ENDPOINT_PATH:-/v1/apitokens/generate}"

# Kubernetes secret namespace and name to store the generated token.
declare -r NAMESPACE="${NAMESPACE:-}"
declare -r SECRET_NAME="${SECRET_NAME:-rhtap-acs-integration}"

#
# Functions
#

fail() {
    echo "# [ERROR] ${*}" >&2
    exit 1
}

assert_variables() {
    [[ -z "${ROX_USERNAME}" ]] &&
        fail "ROX_USERNAME is not set!"
    [[ -z "${ROX_PASSWORD}" ]] &&
        fail "ROX_PASSWORD is not set!"
    [[ -z "${ROX_ENDPOINT}" ]] &&
        fail "ROX_ENDPOINT is not set!"
    [[ -z "${SECRET_NAME}" ]] &&
        fail "SECRET_NAME is not set!"
    [[ -z "${NAMESPACE}" ]] &&
        fail "NAMESPACE is not set!"
}

# Before creating a new secret, delete the existing one if it exists
delete_secret_if_exists() {
    if oc get secret "${SECRET_NAME}" --namespace="${NAMESPACE}" &>/dev/null; then
        echo "# Deleting existing secret '${NAMESPACE}/${SECRET_NAME}'..."
        oc delete secret "${SECRET_NAME}" --namespace="${NAMESPACE}" ||
            fail "Failed to delete existing secret."
    fi
}

# Stores the informed token on a secret, also the API endpoint.
store_api_token_on_secret() {
    declare -r token="${1:-}"
    [[ -z "${token}" ]] &&
        fail "Token is not informed!"

    echo "# Storing StackRox API token on secret '${NAMESPACE}/${SECRET_NAME}'..."
    delete_secret_if_exists && {
        oc create secret generic "${SECRET_NAME}" \
            --namespace="${NAMESPACE}" \
            --from-literal="endpoint=${ROX_ENDPOINT}" \
            --from-literal="token=${token}" ||
            fail "Failed to store StackRox API token on secret."
    }
}

# Generates a StackRox API token and stores the Kubernetes secret configured.
stackrox_generate_api_token() {
    api_url="${ROX_ENDPOINT}${ROX_ENDPOINT_PATH}"
    echo "# Generating StackRox API token on ${api_url}" \
        "for user '${ROX_USERNAME}'..."
    output="$(
        curl \
            --silent \
            --insecure \
            --user "${ROX_USERNAME}:${ROX_PASSWORD}" \
            --data '{"name":"RHTAP", "role": "Admin"}' \
            "${api_url}"
    )"
    [[ $? -ne 0 || -z "${output}" ]] &&
        fail "Failed to generate StackRox API token."

    token="$(echo "${output}" | jq -r '.token')"
    [[ -z "${token}" ]] &&
        fail "Failed to extract StackRox API token."

    store_api_token_on_secret "${token}"
}

#
# Main
#

stackrox_helper() {
    assert_variables
    stackrox_generate_api_token
}

if stackrox_helper; then
    echo "StackRox API token is generated and stored successfully."
    exit 0
else
    echo "Failed to generate and store StackRox API token."
    exit 1
fi
