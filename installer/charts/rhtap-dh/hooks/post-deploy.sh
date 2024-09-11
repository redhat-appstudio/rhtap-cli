#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

get_binaries() {
    if kubectl >/dev/null 2>&1; then
        KUBECTL="kubectl"
    else
        ARCH="$(uname -p | sed -e 's:x86_64:amd64:' -e 's:aarch:arm:')"
        RHEL_VERSION="rhel9"
        OCP_VERSION="4.15.31"
        TARBALL="openshift-client-linux-${ARCH}-${RHEL_VERSION}-${OCP_VERSION}.tar.gz"
        ROOT_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_VERSION}"
        echo "Downloading '${ROOT_URL}/${TARBALL}'"
        curl --proto "https" -L -s "${ROOT_URL}/${TARBALL}" -o "${TARBALL}"
        curl --proto "https" -L -s "${ROOT_URL}/sha256sum.txt" -o sha256sum.txt.tmp
        grep "${TARBALL}" sha256sum.txt.tmp > sha256sum.txt
        sha256sum -c sha256sum.txt
        tar xzf "${TARBALL}"
        KUBECTL="$PWD/kubectl"
    fi
}

app_namespaces() {
    ### Workaround
    ### Helm does not support the patching of resources.
    NAMESPACE="$INSTALLER__DEVELOPERHUB__NAMESPACE"

    for env in "development" "prod" "stage"; do
        for SA in "default" "pipeline"; do
            echo -n "- Patching ServiceAccount '$SA' in '$NAMESPACE-app-$env': "
            until "$KUBECTL" get serviceaccounts --namespace "$NAMESPACE-app-$env" "$SA" >/dev/null 2>&1; do
                echo -n "_"
                sleep 2
            done
            echo -n "."
            "$KUBECTL" patch serviceaccounts --namespace "$NAMESPACE-app-$env" "$SA" --patch "
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
    get_binaries
    app_namespaces
    cd - >/dev/null
    rm -rf "$TEMP_DIR"
    echo
}

main
