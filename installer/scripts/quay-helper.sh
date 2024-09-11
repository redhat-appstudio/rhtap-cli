#!/usr/bin/env bash
#
# Script to initialize the Quay super-user and create a "docker-registry" secret
# with the admin credentials, the secret is enhanced with the "token" and "url"
# needed for later integration with Red Hat Developer Hub.
#
# The script also initializes a new organization using the super-user token
# obtained. For the new organization it needs a name and a different email than
# the super-user's.
#
#

shopt -s inherit_errexit
set -Eeu -o pipefail
set -x

# Quay hostname (FQDN).
declare -r QUAY_HOSTNAME="${QUAY_HOSTNAME:-}"

# Quay super-user credentials.
declare -r QUAY_USERNAME="${QUAY_USERNAME:-admin}"
declare -r QUAY_PASSWORD="${QUAY_PASSWORD:-}"
declare -r QUAY_EMAIL="${QUAY_EMAIL:-admin@localhost}"

# Quay organization name to create and email address.
declare -r QUAY_ORGANIZATION="${QUAY_ORGANIZATION:-rhtap}"
declare -r QUAY_ORGANIZATION_EMAIL="${QUAY_ORGANIZATION_EMAIL:-${QUAY_ORGANIZATION}@localhost}"

# Namespace and secret name to create the "docker-registry" secret.
declare -r NAMESPACE="${NAMESPACE:-}"
declare -r SECRET_NAME="${SECRET_NAME:-}"

# After initialization of the super-user, or login, the global variable will be
# set with the user's access token obtained from Quay.
declare ACCESS_TOKEN=""

#
# Functions
#

fail() {
    echo "# [ERROR] ${*}" >&2
    exit 1
}

warn() {
    echo "# [WARN] ${*}" >&2
}

info() {
    echo "# [INFO] ${*}"
}

assert_variables() {
    [[ -z "${QUAY_HOSTNAME}" ]] &&
        fail "QUAY_HOSTNAME is not set!"
    [[ -z "${QUAY_USERNAME}" ]] &&
        fail "QUAY_USERNAME is not set!"
    [[ -z "${QUAY_PASSWORD}" ]] &&
        fail "QUAY_PASSWORD is not set!"
    [[ -z "${QUAY_EMAIL}" ]] &&
        fail "QUAY_EMAIL is not set!"
    [[ -z "${QUAY_ORGANIZATION}" ]] &&
        fail "QUAY_ORGANIZATION is not set!"
    [[ -z "${QUAY_ORGANIZATION_EMAIL}" ]] &&
        fail "QUAY_ORGANIZATION_EMAIL is not set!"

    [[ "${QUAY_EMAIL}" == "${QUAY_ORGANIZATION_EMAIL}" ]] &&
        fail "QUAY_EMAIL and QUAY_ORGANIZATION_EMAIL must be different!"

    [[ -z "${NAMESPACE}" ]] &&
        fail "NAMESPACE is not set!"
    [[ -z "${SECRET_NAME}" ]] &&
        fail "SECRET_NAME is not set!"
}

# Initializes the Quay super-user with the credentials informed via environment.
quay_initialize_super_user() {
    local quay_url="https://${QUAY_HOSTNAME}/api/v1/user/initialize"
    local data=(
        "{"
        "\"username\": \"${QUAY_USERNAME}\","
        "\"password\": \"${QUAY_PASSWORD}\","
        "\"email\": \"${QUAY_EMAIL}\","
        "\"access_token\": true"
        "}"
    )
    local init_response token message

    info "Initializing Quay super-user..."
    init_response=$(
        curl \
            --silent \
            --insecure \
            --request POST \
            --header 'Content-Type: application/json' \
            --data "${data[*]}" \
            "${quay_url}"
    )
    message=$(echo "${init_response}" | jq --raw-output '.message')

    info "Inspecting Quay initialization response..."
    # Checking the response message to determine if Quay has already been
    # initialized.
    if [[ "${message}" == *"a non-empty database"* ]]; then
        warn "Quay has already been initialized!"
        return 0
    fi

    info "Extracting access token from the response..."
    # When the super user has not been initialized and the response doesn't
    # contain the expected "access_token", the script should fail completely.
    token=$(echo "${init_response}" | jq --raw-output '.access_token')
    if [[ -z "${token}" || "${token}" == "null" ]]; then
        warn "Failed to initialize Quay super-user!"
        return 1
    fi

    info "Quay access token obtained successfully!"
    export ACCESS_TOKEN="${token}"
    return 0
}

# Creates a new organization in Quay with the name informed via environment, using
# the super-user's ACCESS_TOKEN to authorize the request.
quay_create_organization() {
    local quay_url="https://${QUAY_HOSTNAME}/api/v1/organization"
    local data=(
        "{"
        "\"name\": \"${QUAY_ORGANIZATION}\","
        "\"email\": \"${QUAY_ORGANIZATION_EMAIL}\""
        "}"
    )
    local create_response

    info "Creating Quay organization '${QUAY_ORGANIZATION}'..."
    create_response=$(
        curl \
            --silent \
            --insecure \
            --location \
            --request POST \
            --header 'Content-Type: application/json' \
            --header "Authorization: Bearer ${ACCESS_TOKEN}" \
            --data "${data[*]}" \
            "${quay_url}"
    )
    if [[ -z "${create_response}" || "${create_response}" != *"Created"* ]]; then
        warn "Failed to create organization!"
        return 1
    fi
    info "Organization created successfully!"
    return 0
}

# Creates a "docker-registry" secret in the namespace configured location, uses
# the credentials informed to the script to login on the container registry. The
# secret is enhanced with the "token" and "url" fields.
quay_create_secret() {
    info "Trying to create/update the integration secret..."
    if ! (
        oc create secret docker-registry "${SECRET_NAME}" \
            --namespace="${NAMESPACE}" \
            --docker-server="${QUAY_HOSTNAME}" \
            --docker-username="${QUAY_USERNAME}" \
            --docker-password="${QUAY_PASSWORD}" \
            --docker-email="${QUAY_EMAIL}" \
            --dry-run=client \
            --output=yaml |
            oc apply -f -
    ); then
        warn "Failed to create secret!"
        return 1
    fi
    info "Secret created/updated successfully!"

    # Patching the secret to include the "token" and "url" attributes, needed for
    # the later RHDH integration.
    info "Patch secret with 'token' and 'url'..."
    local token url
    local -a patch

    token=$(base64 -w0 <<<"${ACCESS_TOKEN}")
    url=$(base64 -w0 <<<"https://${QUAY_HOSTNAME}")
    patch=(
        "["
        "{\"op\": \"add\", \"path\": \"/data/token\", \"value\": \"${token}\"},"
        "{\"op\": \"add\", \"path\": \"/data/url\", \"value\": \"${url}\"}"
        "]"
    )

    if oc patch secret "${SECRET_NAME}" \
        --namespace="${NAMESPACE}" \
        --type=json \
        --patch="${patch[*]}"; then
        info "Secret patched successfully with 'token' and 'url' added!"
        return 0
    fi
    return 1
}

# Initializes the Quay super-user and creates a "docker-registry" secret with the
# credentials informed via environment variables.
quay_helper() {
    info "Initializing Quay helper..."
    info "Quay hostname: '${QUAY_HOSTNAME}'"
    info "Quay username: '${QUAY_USERNAME}'"
    info "Secret namespace/name: '${NAMESPACE}/${SECRET_NAME}'"

    quay_initialize_super_user || {
        warn "Failed to initialize super-user!"
        return 1
    }

    # Checking if Quay has already been initialized, thus the secret doesn't need
    # to get recreated, the acccess token is only obtained during initialization
    if oc get secret "${SECRET_NAME}" --namespace="${NAMESPACE}" &>/dev/null &&
        [[ -z "${ACCESS_TOKEN}" ]]; then
        warn "Secret already exists, Quay has already been initialized!"
        return 0
    fi

    quay_create_secret || {
        warn "Failed to create secret!"
        return 1
    }

    quay_create_organization || {
        warn "Failed to create organization!"
        return 1
    }

    return 0
}

#
# Main
#

retry_quay_helper() {
    assert_variables
    for i in {1..30}; do
        wait=$((i * 5))
        info "[${i}/30] Waiting for ${wait} seconds before retrying..."
        sleep ${wait}

        info "Trying to initialize Quay super-user..."
        quay_helper &&
            return 0
    done
    return 1
}

if retry_quay_helper; then
    echo "# [INFO] Quay helper succeeded."
else
    fail "Quay helper failed!"
fi
