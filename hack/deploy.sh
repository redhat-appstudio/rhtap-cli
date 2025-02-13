#!/usr/bin/env bash

# Manage a full deployment of RHTAP based on values from an env file
# and a few parameters

# shellcheck disable=SC2016

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(
    cd "$(dirname "$0")" >/dev/null
    pwd
)"

usage() {
    echo "
Usage:
    ${0##*/} [options]

Optional arguments:
    -c, --container NAME
        Run the cli from a container. Use 'dev' to build from source.
    -e, --env-file
        Environment variables definitions (default: $SCRIPT_DIR/private.env)
    -i, --integration INTEGRATION
        Use an external service [acs, bitbucket, ci, dh, github, gitlab, gitops,
        jenkins, quay, tas, tpa].
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/} -e private.env -i acs -i quay
" >&2
}

parse_args() {
    PROJECT_DIR="$(
        cd "$(dirname "$SCRIPT_DIR")" >/dev/null
        pwd
    )"
    ENVFILE="$SCRIPT_DIR/private.env"
    KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
    CLI_BIN="run_bin"
    CLI="$CLI_BIN"
    while [[ $# -gt 0 ]]; do
        case $1 in
        -c|--container)
            CLI_IMAGE="$2"
            CLI="run_container"
            CLI_PORT="8228"
            shift
            ;;
        -e | --env-file)
            ENVFILE="$(readlink -e "$2")"
            shift
            ;;
        -i|--integration)
            case $2 in
            acs)
                ACS=1
                ;;
            bitbucket)
                BITBUCKET=1
                ;;
            ci)
                CI=1
                ;;
            dh)
                DH=1
                ;;
            github)
                GITHUB=1
                ;;
            gitlab)
                GITLAB=1
                ;;
            gitops)
                GITOPS=1
                ;;
            jenkins)
                JENKINS=1
                ;;
            quay)
                QUAY=1
                ;;
            tas)
                TAS=1
                ;;
            tpa)
                TPA=1
                ;;
            *)
                echo "[ERROR] Unknown integration: $1"
                usage
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

    # shellcheck disable=SC1090
    source "$ENVFILE"
}

init() {
    cd "$PROJECT_DIR"
}

build() {
    if [ "$CLI" = "run_bin" ]; then
        make
    else
        if [ "${CLI_IMAGE:-}" = "dev" ]; then
            podman build . -t rhtap-cli
            CLI_IMAGE="rhtap-cli:latest"
        fi
    fi
}

init_config() {
    CONFIG_DIR="$SCRIPT_DIR/config"
    mkdir -p "$CONFIG_DIR"
    CONFIG="$CONFIG_DIR/config.yaml"
    VALUES="$CONFIG_DIR/values.yaml.tpl"

    unshare

    cp "$PROJECT_DIR/installer/config.yaml" "$CONFIG"
    cp "$PROJECT_DIR/installer/charts/values.yaml.tpl" "$VALUES"
    cp "$KUBECONFIG" "$CONFIG_DIR/kubeconfig"
    KUBECONFIG="$CONFIG_DIR/kubeconfig"

    NAMESPACE="$(yq '.rhtapCLI.namespace' "$CONFIG")"
    export NAMESPACE

    # shellcheck disable=SC1090
    source "$ENVFILE"
}

rhtap_cli() {
    $CLI "$@"
}

run_bin() {
    eval "$PROJECT_DIR/bin/rhtap-cli --config='$CONFIG' $*"
}

run_container() {
    podman run \
        --entrypoint="bash" \
        --env-file="$ENVFILE" \
        --publish "$CLI_PORT:$CLI_PORT" \
        --rm \
        --volume="$KUBECONFIG:/rhtap-cli/.kube/config:Z,U" \
        --volume="$CONFIG:/rhtap-cli/my-config.yaml:Z,U" \
        "$CLI_IMAGE" \
        -c "rhtap-cli --config=my-config.yaml $*"
    unshare
}

unshare() {
    podman unshare chown -R 0:0 "$CONFIG_DIR"
}

configure() {
    if [ -n "${CATALOG_URL:-}" ]; then
        export CATALOG_URL
        yq -i '.rhtapCLI.features.redHatDeveloperHub.properties.catalogURL=strenv(CATALOG_URL)' "$CONFIG"
    fi

    if [[ -n "${ACS:-}" ]]; then
        yq -i '.rhtapCLI.features.redHatAdvancedClusterSecurity.enabled=false' "$CONFIG"
    fi
    if [[ -n "${CI:-}" ]]; then
        sed -i 's/\( *ci\): .*/\1: true/' "$VALUES"
    fi
    if [[ -n "${DH:-}" ]]; then
        yq -i '.rhtapCLI.dependencies[] |= select(.chart == "charts/rhtap-dh").enabled = false' "$CONFIG"
    fi
    if [[ -n "${GITOPS:-}" ]]; then
        yq -i '.rhtapCLI.features.openShiftGitOps.enabled=false' "$CONFIG"
    fi
    if [[ -n "${QUAY:-}" ]]; then
        yq -i '.rhtapCLI.features.redHatQuay.enabled=false' "$CONFIG"
    fi
    if [[ -n "${TAS:-}" ]]; then
        yq -i '.rhtapCLI.features.trustedArtifactSigner.enabled=false' "$CONFIG"
    fi
    if [[ -n "${TPA:-}" ]]; then
        yq -i '.rhtapCLI.features.trustedProfileAnalyzer.enabled=false' "$CONFIG"
    fi
}

integrations() {
    if [[ -n "${ACS:-}" ]]; then
        rhtap_cli integration acs --force \
            --endpoint='"$ACS__CENTRAL_ENDPOINT"' \
            --token='"$ACS__API_TOKEN"'
    fi
    if [[ -n "${BITBUCKET:-}" ]]; then
        rhtap_cli integration bitbucket --force \
            --app-password='"$BITBUCKET__APP_PASSWORD"' \
            --host='"$BITBUCKET__HOST"' \
            --username='"$BITBUCKET__USERNAME"'
    fi
    if [[ -n "${GITHUB:-}" ]]; then
        if ! kubectl get secret -n "$NAMESPACE" rhtap-github-integration >/dev/null 2>&1; then
            rhtap_cli integration github-app \
                --create \
                --token='"$GITHUB__ORG_TOKEN"' \
                --org='"$GITHUB__ORG"' \
                "rhtap-$GITHUB__ORG-$(date +%m%d-%H%M)"
        fi
    fi
    if [[ -n "${GITLAB:-}" ]]; then
        if [[ -n "${GITLAB__APP__CLIENT__ID:-}" && -n "${GITLAB__APP__CLIENT__SECRET:-}" ]]; then
            rhtap_cli integration gitlab --force \
                --app-id='"$GITLAB__APP__CLIENT__ID"' \
                --app-secret='"$GITLAB__APP__CLIENT__SECRET"' \
                --host='"$GITLAB__HOST"' \
                --token='"$GITLAB__TOKEN"'
        else
            rhtap_cli integration gitlab --force \
                --host='"$GITLAB__HOST"' \
                --token='"$GITLAB__TOKEN"'
        fi
    fi
    if [[ -n "${JENKINS:-}" ]]; then
        rhtap_cli integration jenkins --force \
            --token='"$JENKINS__TOKEN"' \
            --url='"$JENKINS__URL"' \
            --username='"$JENKINS__USERNAME"'
    fi
    if [[ -n "${QUAY:-}" ]]; then
        rhtap_cli integration quay --force \
            --dockerconfigjson='"$QUAY__DOCKERCONFIGJSON"' \
            --token='"$QUAY__API_TOKEN"' --url='"$QUAY__URL"'
    fi
}

deploy() {
    time rhtap_cli deploy "${DEBUG:-}"
}

configure_ci() {
    "$SCRIPT_DIR/ci-set-org-vars.sh" --env-file "$ENVFILE"
}

action() {
    build
    init_config
    configure
    integrations
    deploy
    configure_ci
}

main() {
    parse_args "$@"
    init
    action
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
fi
