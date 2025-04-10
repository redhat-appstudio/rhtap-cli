#!/usr/bin/env bash

# Creates a release branch, and sets tags.

set -o errexit
set -o nounset
set -o pipefail

usage() {
    echo "
Usage:
    ${0##*/} [options]

Optional arguments:
    --dry-run
        Do not push updates back to the upstream.
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/}
" >&2
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        --dry-run)
            DRY_RUN=1
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
    TMP_DIR=$(mktemp -d)
    PROJECT_DIR="$TMP_DIR/rhtap-cli"
    trap cleanup EXIT

    git clone git@github.com:redhat-appstudio/rhtap-cli.git "$PROJECT_DIR"
    cd "$PROJECT_DIR"
}

cleanup() {
    if [ -z "${DRY_RUN:-}" ]; then
        rm -rf "$TMP_DIR"
    else
        echo "You can browse the repository: $PROJECT_DIR"
    fi
}

get_version() {
    VERSION_XY="$(
        yq '.subscriptions.'"$1"'.channel' installer/charts/rhtap-subscriptions/values.yaml \
        | grep --extended-regexp "[0-9.]*" --only-matching
    )"
    VERSION_XYZ="$VERSION_XY.0"
    export VERSION_XY VERSION_XYZ
}

update_charts() {
    # Bump "version" in all charts
    get_version "redHatDeveloperHub"
    RELEASE_BRANCH="release-$VERSION_XY"
    find installer/charts/ -name Chart.yaml | while read -r CHART; do
        yq -i '.version = strenv(VERSION_XYZ)' "$CHART"
    done

    # Bump "appVersion" in all charts
    get_version "openshiftGitOps"
    yq -i '.appVersion = strenv(VERSION_XY)' "installer/charts/rhtap-gitops/Chart.yaml"
    get_version "openshiftPipelines"
    yq -i '.appVersion = strenv(VERSION_XY)' "installer/charts/rhtap-pipelines/Chart.yaml"
    get_version "openshiftTrustedArtifactSigner"
    yq -i '.appVersion = strenv(VERSION_XY)' "installer/charts/rhtap-tas/Chart.yaml"
    get_version "redHatAdvancedClusterSecurity"
    yq -i '.appVersion = strenv(VERSION_XY)' "installer/charts/rhtap-acs/Chart.yaml"
    yq -i '.appVersion = strenv(VERSION_XY)' "installer/charts/rhtap-acs-test/Chart.yaml"
    get_version "redHatDeveloperHub"
    yq -i '.appVersion = strenv(VERSION_XY)' "installer/charts/rhtap-dh/Chart.yaml"
    get_version "redHatQuay"
    yq -i '.appVersion = strenv(VERSION_XY)' "installer/charts/rhtap-quay/Chart.yaml"
}

update_template() {
    CONFIG="installer/config.yaml"
    get_version "redHatDeveloperHub"
    CATALOG_URL="https://github.com/redhat-appstudio/tssc-sample-templates/blob/v$VERSION_XYZ/all.yaml" \
    yq -i '.rhtapCLI.features.redHatDeveloperHub.properties.catalogURL = strenv(CATALOG_URL)' "$CONFIG"
}

commit_freeze() {
    git commit \
        --all \
        --message "chore: code freeze for $RELEASE_BRANCH"
    git tag "v$VERSION_XY-freeze"
}

update_ci() {
    for PLR in ".tekton/rhtap-cli-pull-request.yaml" ".tekton/rhtap-cli-push.yaml"; do
        sed -i "s|\"main\"|\"$RELEASE_BRANCH\"|" "$PLR"
        sed -i "s|  *appstudio\.openshift\.io/application: rhtap-cli|\0-$VERSION_XY|" "$PLR"
        sed -i "s|  *appstudio\.openshift\.io/component: rhtap-cli|\0-$VERSION_XY|" "$PLR"
    done
    yq eval '.spec.params |= map(select(.name != "image-expires-after"))' ".tekton/rhtap-cli-push.yaml"
}

commit_release() {
    git switch -c "$RELEASE_BRANCH"
    git commit \
        --all \
        --message "chore: update PLR to setup Konflux for $RELEASE_BRANCH"
}

code_freeze() {
    update_charts
    update_template
    commit_freeze
}

release_branch() {
    update_ci
    commit_release
}

push_changes() {
    git push --tags --set-upstream origin main
    git push --tags --set-upstream origin "$RELEASE_BRANCH"
}

action() {
    init
    code_freeze
    release_branch
    if [ -z "${DRY_RUN:-}" ]; then
        push_changes
    fi
}

main() {
    parse_args "$@"
    action
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
fi
