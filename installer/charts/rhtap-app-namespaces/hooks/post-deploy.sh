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

    # Wait until the ServiceAccount is available and get the definition
    until "$KUBECTL" get serviceaccounts --namespace "$NAMESPACE" "$SA" >/dev/null 2>&1; do
        echo -n "_"
        sleep 2
    done
    SA_DEFINITION="service-account.yaml"
    SA_DEFINITION_UPDATED="$SA_DEFINITION.patch.yaml"
    "$KUBECTL" get serviceaccount "$SA" --namespace "$NAMESPACE" -o json >"$SA_DEFINITION"

    # Check for artifactory-auth, nexus-auth and quay-auth secrets and patch if present
    [ -e "$SA_DEFINITION_UPDATED" ] && rm "$SA_DEFINITION_UPDATED"
    for SECRET_NAME in artifactory-auth nexus-auth quay-auth; do
        SECRET=$("$KUBECTL" get secret "$SECRET_NAME" --namespace "$NAMESPACE" --ignore-not-found)
        if [ -n "$SECRET" ]; then
            echo -n "."
            jq --arg NAME "$SECRET_NAME" '
                .secrets |= (. + [{"name": $NAME}] | unique) |
                .imagePullSecrets |= (. + [{"name": $NAME}] | unique)
            ' "$SA_DEFINITION" >"$SA_DEFINITION_UPDATED"
            cp "$SA_DEFINITION_UPDATED" "$SA_DEFINITION"
        fi
    done

    echo "OK"
    if [ -e "$SA_DEFINITION_UPDATED" ]; then
        "$KUBECTL" apply -f "$SA_DEFINITION_UPDATED"
    fi
}

app_namespaces() {
    NAMESPACE="$INSTALLER__QUAY__SECRET__NAMESPACE"

    patch_serviceaccount "$NAMESPACE-app-ci" "pipeline"
    for env in "ci" "development" "prod" "stage"; do
        patch_serviceaccount "$NAMESPACE-app-$env" "default"
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
