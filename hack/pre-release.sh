#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(
    cd "$(dirname "$0")" >/dev/null
    pwd
)"

PROJECT_DIR="$(
    cd "$SCRIPT_DIR/.." >/dev/null
    pwd
)"

usage() {
    echo "
Usage:
    ${0##*/} [options]

Optional arguments:
    -p, --product PRODUCT
        The product on which to activate the pre-release subscription.
        Can be specified multiple times.
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/}
" >&2
}

parse_args() {
    PRODUCT_LIST=()
    while [[ $# -gt 0 ]]; do
        case $1 in
        -p|--product)
            case ${2:-} in
            developerHub|dh|rhdh)
                PRODUCT_LIST+=( "rhdh" )
                ;;
            gitops|pipelines)
                PRODUCT_LIST+=( "$2" )
                ;;
            trusted-artifact-signer|tas|rhtas)
                PRODUCT_LIST+=( "rhtas" )
                ;;
            "")
                echo "[ERROR] Product name needs to be specified after '--product'."
                usage
                exit 1
                ;;
            *)
                echo "[ERROR] Unknown product: $2"
                usage
                exit 1
                ;;
            esac
            shift
            ;;
        -d | --debug)
            set -x
            DEBUG="--debug"
            export DEBUG
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown argument: $1"
            usage
            exit 1
            ;;
        esac
        shift
    done
}

init() {
    SHARED_DIR="$(mktemp -d)"
    cd "$SHARED_DIR"
    export SHARED_DIR
    trap cleanup EXIT
}

cleanup() {
    rm -rf "$SHARED_DIR"
}

h1() {
    echo "
################################################################################
# $1
################################################################################
"
}

configure_gitops(){
    # GITOPS_IIB_IMAGE="quay.io/rhtap_qe/gitops-iib:782137"

    SUBSCRIPTION="openshiftGitOps"
    CHANNEL="latest"
    SOURCE="gitops-iib"
}

configure_pipelines(){
    # PIPELINES_IMAGE="quay.io/openshift-pipeline/openshift-pipelines-pipelines-operator-bundle-container-index"
    # PIPELINES_IMAGE_TAG="v4.17-candidate"

    SUBSCRIPTION="openshiftPipelines"
    CHANNEL="latest"
    SOURCE="pipelines-iib"
}

configure_rhdh(){
    RHDH_INSTALL_SCRIPT="https://raw.githubusercontent.com/redhat-developer/rhdh-operator/main/.rhdh/scripts/install-rhdh-catalog-source.sh"
    curl -sSLO $RHDH_INSTALL_SCRIPT
    chmod +x install-rhdh-catalog-source.sh

    ./install-rhdh-catalog-source.sh --latest --install-operator rhdh

    SUBSCRIPTION="developerHub"
    CHANNEL="fast-1.7"
    SOURCE="rhdh-fast"
}

configure_rhtas() {
    # Configure CatalogSource
    echo '
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: rhtas-operator
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  grpcPodConfig:
    securityContextConfig: legacy
  publisher: Red Hat
  image: quay.io/securesign/fbc-v4-18@sha256:124d3fcff0c711ba8d03a405a36b0e128a900065e0687885e626e0b4153ec804
  displayName: TAS Operator
' \
    | oc apply -f -

    # Configure ImageDigestMirrorSet
    echo '
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: registry-stage
spec:
  imageDigestMirrors:
    - mirrors:
        - registry.stage.redhat.io/rhtas
      source: registry.redhat.io/rhtas
' \
    | oc apply -f -

    # Configure pull-secret
    DOCKERCONFIGJSON=$(
        oc get secrets \
            -n openshift-config pull-secret \
            -o jsonpath='{.data.\.dockerconfigjson}' \
        | base64 -d
    )

    echo "
kind: Secret
apiVersion: v1
metadata:
  name: pull-secret
  namespace: openshift-config
stringData:
  .dockerconfigjson: |
    $DOCKERCONFIGJSON
type: kubernetes.io/dockerconfigjson
" \
    | oc apply -f -

    SUBSCRIPTION="openshiftTrustedArtifactSigner"
    CHANNEL="stable-v1.2"
    SOURCE="rhtas-operator"
}

configure_subscription(){
    # Prepare for pre-release install capabilities
    subscription_values_file="$PROJECT_DIR/installer/charts/tssc-subscriptions/values.yaml"

    yq -i "
        .subscriptions.$SUBSCRIPTION.channel = \"$CHANNEL\",
        .subscriptions.$SUBSCRIPTION.source = \"$SOURCE\"
    " "$subscription_values_file"
}

main() {
    parse_args "$@"
    init
    for PRODUCT in $(echo "${PRODUCT_LIST[@]}" | tr " " "\n" | sort); do
        h1 "Configuring $PRODUCT"
        "configure_$PRODUCT"
        configure_subscription
        echo
    done
    echo "Done"
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
fi
