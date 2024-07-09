#!/usr/bin/env bash
#
# Uses the ArgoCD credentials to create a secret in the cluster. The credentials
# are stored in an "env file" format sourced by this script, and later on using
# "kubectl" to create the secret.
#

shopt -s inherit_errexit
set -Eeu -o pipefail

# Target secret name, to be created with ArgoCD credentials.
declare -r SECRET_NAME="${SECRET_NAME:-rhtap-argocd-integration}"
# Secret's namespace.
declare -r NAMESPACE="${NAMESPACE:-}"

# Environment file to store the ArgoCD credentials.
declare -r ARGOCD_ENV_FILE="${ARGOCD_ENV_FILE:-/rhtap/argocd/env}"

fail() {
    echo "# [ERROR] ${*}" >&2
    exit 1
}

# Waits for the environment file to be available.
wait_for_env_file() {
    echo "# Waiting for '${ARGOCD_ENV_FILE}' to be available..."
    for i in {1..30}; do
        wait=$((i * 5))
        echo "### [${i}/30] Waiting for '${ARGOCD_ENV_FILE}' to be available..."
        sleep ${wait}

        [[ -r "${ARGOCD_ENV_FILE}" ]] &&
            return 0
    done
    return 1
}

# Stores the ArgoCD credentials in a Kubernetes secret.
argocd_store_token() {
    echo "# Asserting required environment variables..."
    [[ -z "${SECRET_NAME}" ]] &&
        fail "SECRET_NAME is not set!"
    [[ -z "${NAMESPACE}" ]] &&
        fail "NAMESPACE is not set!"

    [[ -z "${ARGOCD_ENV_FILE}" ]] &&
        fail "ARGOCD_ENV_FILE is not set!"

    wait_for_env_file ||
        fail "ARGOCD_ENV_FILE='${ARGOCD_ENV_FILE}' not found or not readable!"

    echo "# Sourcing ArgoCD credentials from '${ARGOCD_ENV_FILE}'..."
    # shellcheck source=/dev/null
    . "${ARGOCD_ENV_FILE}"

    [[ -z "${ARGOCD_HOSTNAME}" ]] &&
        fail "ARGOCD_HOSTNAME is not set!"
    [[ -z "${ARGOCD_USER}" ]] &&
        fail "ARGOCD_USER is not set!"
    [[ -z "${ARGOCD_PASSWORD}" ]] &&
        fail "ARGOCD_PASSWORD is not set!"
    [[ -z "${ARGOCD_API_TOKEN}" ]] &&
        fail "ARGOCD_API_TOKEN is not set!"

    # Using the dry-run flag to generate the secret payload, and later on "kubectl
    # apply" to create, or update, the secret payload in the cluster.
    echo "# Creating secret '${SECRET_NAME}' in namespace '${NAMESPACE}'..."
    if ! (
        kubectl create secret generic "${SECRET_NAME}" \
            --namespace="${NAMESPACE}" \
            --from-literal="ARGOCD_HOSTNAME=${ARGOCD_HOSTNAME}" \
            --from-literal="ARGOCD_USER=${ARGOCD_USER}" \
            --from-literal="ARGOCD_PASSWORD=${ARGOCD_PASSWORD}" \
            --from-literal="ARGOCD_API_TOKEN=${ARGOCD_API_TOKEN}" \
            --dry-run="client" \
            --output="yaml" |
            kubectl apply -f -
    ); then
        fail "Secret '${SECRET_NAME}' could not be created!"
    fi
    return 0
}

if argocd_store_token; then
    echo "# ArgoCD credentials stored successfully!"
    exit 0
else
    fail "ArgoCD credentials could not be stored!"
fi
