#!/usr/bin/env bash
#
# Script to test the tokens for the SCMs.
#

shopt -s inherit_errexit
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

usage() {
    echo "
Usage:
    ${0##*/} [options] SCM

Optional arguments:
    -h, --host HOST
        SCM host, eg 'github.com'.
    --insecure
        Disable TLS certificate validation.
    -s, --scm SCM
        SCM vendor, eg 'github'.
    -t, --token TOKEN
        Authentication token.
    -d, --debug
        Activate tracing/debug mode.
    --help
        Display this message.

Example:
    ${0##*/} -h github.com -s github -t ghp_myToken
" >&2
}

parse_args() {
    CURL_OPTS+=("--fail" "--location" "--output" "/dev/null" "--silent")
    while [[ $# -gt 0 ]]; do
        case $1 in
        -h | --host)
            HOST="$2"
            shift
            ;;
        --insecure)
            CURL_OPTS+=("--insecure")
            ;;
        -s | --scm)
            SCM="$2"
            shift
            ;;
        -t | --token)
            TOKEN="$2"
            shift
            ;;
        -d | --debug)
            set -x
            DEBUG="--debug"
            export DEBUG
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            usage
            fail "Unknow argument: $1"
            ;;
        esac
        shift
    done
    if [ -z "${HOST:-}" ]; then
        fail "Missing host"
    fi
    if [ -z "${SCM:-}" ]; then
        fail "Missing scm"
    fi
    if [ -z "${TOKEN:-}" ]; then
        fail "Missing token"
    fi
}

#
# Functions
#

fail() {
    echo "# [ERROR] ${*}" >&2
    exit 1
}

warn() {
    echo "# [WARN] ${*}" >&2
}

info() {
    echo "# [INFO] ${*}"
}

github() {
    URL="https://api.$HOST/emojis"
    curl "${CURL_OPTS[@]}" \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer $TOKEN" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        "$URL"
}

#
# Main
#
main() {
    parse_args "$@"
    info "Testing $HOST integration token"
    $SCM || fail "Token is not valid"
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
    main "$@"
    echo "Success"
fi
