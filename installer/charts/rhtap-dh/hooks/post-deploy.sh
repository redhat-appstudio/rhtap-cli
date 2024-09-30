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
    echo -n "."

    # Check for quay-auth and nexus-auth secrets and patch if present
    QUAY_SECRET=$("$KUBECTL" get secret quay-auth --namespace "$NAMESPACE" --ignore-not-found)
    NEXUS_SECRET=$("$KUBECTL" get secret nexus-auth --namespace "$NAMESPACE" --ignore-not-found)

    SECRET_NAME=""
    if [ -n "$QUAY_SECRET" ]; then
        SECRET_NAME="  - name: quay-auth"
    fi

    if [ -n "$NEXUS_SECRET" ]; then
        if [ -n "$SECRET_NAME" ]; then
            SECRET_NAME="$SECRET_NAME
  - name: nexus-auth"
        else
            SECRET_NAME="  - name: nexus-auth"
        fi
    fi

    if [ -n "$SECRET_NAME" ]; then
        "$KUBECTL" patch serviceaccounts --namespace "$NAMESPACE" "$SA" --patch "
secrets:
$SECRET_NAME
imagePullSecrets:
$SECRET_NAME
" >/dev/null
        echo "OK"
    else
        echo "No quay-auth or nexus-auth secrets found, skipping patch."
    fi
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
