#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

app_namespaces() {
    ### Workaround
    ### Helm does not support the patching of resources.
    NAMESPACE="$INSTALLER__DEVELOPERHUB__NAMESPACE"

    for env in "development" "prod" "stage"; do
        for SA in "default" "pipeline"; do
            echo -n "- Patching ServiceAccount '$SA' in '$NAMESPACE-app-$env': "
            until kubectl get serviceaccounts --namespace "$NAMESPACE-app-$env" "$SA" >/dev/null 2>&1; do
                echo -n "_"
                sleep 2
            done
            echo -n "."
            kubectl patch serviceaccounts --namespace "$NAMESPACE-app-$env" "$SA" --patch "
secrets:
    - name: quay-auth
imagePullSecrets:
    - name: quay-auth
" >/dev/null
            echo "OK"
        done
    done
}

#
# Main
#
main() {
    TEMP_DIR="$(mktemp -d)"
    cd "$TEMP_DIR"
    app_namespaces
    cd - >/dev/null
    rm -rf "$TEMP_DIR"
    echo
}

main
