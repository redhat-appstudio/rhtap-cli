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

# Stores the new token and API endpoint in a secret.
store_api_token_in_secret() {
    declare -r token="${1:-}"
    [[ -z "${token}" ]] &&
        fail "Token is not informed!"

    echo "# Storing StackRox API token on secret '${NAMESPACE}/${SECRET_NAME}'..."
    if ! oc create secret generic "${SECRET_NAME}" \
            --namespace="${NAMESPACE}" \
            --from-literal="endpoint=${ROX_ENDPOINT}:443" \
            --from-literal="token=${token}" \
            --dry-run="client" \
            --output="yaml" |
            kubectl apply -f -; then
        fail "Failed to store StackRox API token in a secret."
    fi
}

# Generates a StackRox API token and stores it as a Kubernetes secret.
stackrox_generate_api_token() {
    api_url="https://${ROX_ENDPOINT}${ROX_ENDPOINT_PATH}"
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
}

#
# Main
#

stackrox_helper() {
    assert_variables
    stackrox_generate_api_token
    store_api_token_in_secret "${token}"
}

if stackrox_helper; then
    echo "StackRox API token is generated and stored successfully."
    exit 0
else
    echo "Failed to generate and store StackRox API token."
    exit 1
fi
