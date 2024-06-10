#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

app_namespaces() {
    ### Workaround
    ### Helm does not support the patching of resources.
    echo -n "* Patching ServiceAccounts in rhtap-app-*: "
    for env in "development" "prod" "stage"; do
        for SA in "default" "pipeline"; do
            until kubectl get serviceaccounts --namespace "rhtap-app-$env" "$SA" >/dev/null 2>&1; do
                echo -n "_"
                sleep 2
            done
            echo -n "."
            kubectl patch serviceaccounts --namespace "rhtap-app-$env" "$SA" --patch "
secrets:
    - name: quay-auth
imagePullSecrets:
    - name: quay-auth
" >/dev/null
        done
    done
    echo "OK"
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
}

main
