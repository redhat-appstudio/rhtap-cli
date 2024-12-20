#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

get_binaries() {
    if kubectl >/dev/null 2>&1; then
        KUBECTL="kubectl"
        return
    fi
    if oc >/dev/null 2>&1; then
        KUBECTL="oc"
        return
    fi

    echo "[ERROR] 'kubectl' or 'oc' not found" >&2
    exit 1
}

patch_serviceaccount() {
    local NAMESPACE="$1"
    local SA="$2"

    echo -n "- Patching ServiceAccount '$SA' in '$NAMESPACE': "

    # Wait until the ServiceAccount is available
    until "$KUBECTL" get serviceaccounts --namespace "$NAMESPACE" "$SA" >/dev/null 2>&1; do
        echo -n "_"
        sleep 2
    done

    # Check for  artifactory-auth, nexus-auth and quay-auth secrets and patch if present
    for SECRET_NAME in artifactory-auth nexus-auth quay-auth; do
        SECRET=$("$KUBECTL" get secret "$SECRET_NAME" --namespace "$NAMESPACE" --ignore-not-found)
        if [ -n "$SECRET" ]; then
            echo -n "."
            CURRENT_SA_PATCH=$("$KUBECTL" get serviceaccount "$SA" --namespace "$NAMESPACE" -o json)
            UPDATED_SA=$(echo "$CURRENT_SA_PATCH" | jq --arg NAME "$SECRET_NAME" '
                .secrets |= (. + [{"name": $NAME}] | unique) |
                .imagePullSecrets |= (. + [{"name": $NAME}] | unique)
            ')

            echo "$UPDATED_SA" | "$KUBECTL" apply -f -
            echo "OK"
        fi
    done
}

app_namespaces() {
    NAMESPACE="$INSTALLER__DEVELOPERHUB__NAMESPACE"

    for env in "development" "prod" "stage"; do
        for SA in "default" "pipeline"; do
            patch_serviceaccount "$NAMESPACE-app-$env" "$SA"
        done
    done
}

#
# Main
#
main() {
    TEMP_DIR="$(mktemp -d)"
    cd "$TEMP_DIR"
    get_binaries
    app_namespaces
    cd - >/dev/null
    rm -rf "$TEMP_DIR"
    echo
}

main
