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

    SUBSCRIPTION="redHatDeveloperHub"
    CHANNEL="fast-1.5"
    SOURCE="rhdh-fast"
}

configure_subscription(){
    # Prepare for pre-release install capabilities
    subscription_values_file="$PROJECT_DIR/installer/charts/rhtap-subscriptions/values.yaml"

    yq -i "
        .subscriptions.$SUBSCRIPTION.channel = \"$CHANNEL\",
        .subscriptions.$SUBSCRIPTION.source = \"$SOURCE\"
    " "$subscription_values_file"
}

main() {
    parse_args "$@"
    init
    for PRODUCT in "${PRODUCT_LIST[@]}"; do

        "configure_$PRODUCT"
        configure_subscription
    done
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
fi
