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

openshift_gitops() {
    NAMESPACE="rhtap"
    RHTAP_ARGOCD_INSTANCE="$NAMESPACE-argocd"

    echo -n "* Installing 'argocd' CLI: "
    curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod 555 argocd
    ./argocd version --client | head -1 | cut -d' ' -f2

    echo -n "* Wait for ArgoCD instance: "
    until kubectl get route -n "$NAMESPACE" "$RHTAP_ARGOCD_INSTANCE-server" >/dev/null 2>&1; do
        echo -n "_"
        sleep 2
    done
    echo "OK"

    ### Workaround
    ### The ArgoCD token cannot be created via a manifest.
    echo -n "* Configure ArgoCD admin user: "
    RHTAP_ARGOCD_SECRET="rhtap-argocd-integration"
    if [ "$(kubectl get secret "$RHTAP_ARGOCD_SECRET" -n "$NAMESPACE" -o name --ignore-not-found | wc -l)" = "0" ]; then
        ARGOCD_HOSTNAME="$(kubectl get route -n "$NAMESPACE" "$RHTAP_ARGOCD_INSTANCE-server" --ignore-not-found -o jsonpath="{.spec.host}")"
        echo -n "."
        ARGOCD_PASSWORD="$(kubectl get secret -n "$NAMESPACE" "$RHTAP_ARGOCD_INSTANCE-cluster" -o jsonpath="{.data.admin\.password}" | base64 --decode)"
        echo -n "."
        RETRY=0
        while ! ./argocd login "$ARGOCD_HOSTNAME" --grpc-web --insecure --http-retry-max 5 --username admin --password "$ARGOCD_PASSWORD" >/dev/null; do
            if [ "$RETRY" = "20" ]; then
                echo "FAIL"
                echo "[ERROR] Could not login to ArgoCD" >&2
                exit 1
            else
                echo -n "_"
                RETRY=$((RETRY + 1))
                sleep 5
            fi
        done
        echo -n "."
        ARGOCD_API_TOKEN="$(./argocd account generate-token --http-retry-max 5 --account "admin")"
        echo -n "."
        kubectl create secret generic "$RHTAP_ARGOCD_SECRET" \
            --namespace="$NAMESPACE" \
            --from-literal="ARGOCD_API_TOKEN=$ARGOCD_API_TOKEN" \
            --from-literal="ARGOCD_HOSTNAME=$ARGOCD_HOSTNAME" \
            --from-literal="ARGOCD_PASSWORD=$ARGOCD_PASSWORD" \
            --from-literal="ARGOCD_USER=admin" \
            > /dev/null
    fi
    echo "OK"
}

#
# Main
#
main() {
    TEMP_DIR="$(mktemp -d)"
    cd "$TEMP_DIR"
    app_namespaces
    openshift_gitops
    cd - >/dev/null
    rm -rf "$TEMP_DIR"
}

main
