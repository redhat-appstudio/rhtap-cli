#!/usr/bin/env bash
#
# Test whether the informed URL is online, and returning the expected status code.
#

shopt -s inherit_errexit
set -Eeu -o pipefail

# Target URL to test.
declare -r URL="${URL:-}"

# Expected HTTP status code. Default to 200.
declare -r STATUS_CODE="${STATUS_CODE:-200}"

#
# Functions
#

# Tests if the URL is online and returns the expected HTTP status code.
probe_url() {
    local response_code

    echo "# INFO: Probing URL '${URL}' for the status code '${STATUS_CODE}'... "

    # Fetch the HTTP status code from the URL.
    response_code=$(
        curl \
            --silent \
            --show-error \
            --fail \
            --location \
            --insecure \
            --max-time 30 \
            --output /dev/null \
            --write-out "%{http_code}" \
            "${URL}"
    ) || curl_exit=${?}
    
    if [[ "${curl_exit:-0}" -ne 0 ]]; then
        echo "# ERROR: Failed to fetch URL '${URL}', returned '${curl_exit}'." >&2
        return 1
    fi

    if [[ "${response_code}" -eq "${STATUS_CODE}" ]]; then
        echo "# INFO: URL '${URL}' is online and returned '${response_code}'."
        return 0
    else
        echo "# ERROR: '${URL}' returned status code '${response_code}'" \
            " expected ${STATUS_CODE}." >&2
        return 1
    fi
}

#
# Main
#

test_url() {
    if [[ -z "${URL}" ]]; then
        echo "# ERROR: URL environment variable is not set." >&2
        exit 1
    fi

    if [[ -z "${STATUS_CODE}" ]]; then
        echo "# ERROR: STATUS_CODE environment variable is not set." >&2
        exit 1
    fi

    # Probe the URL until it returns the expected HTTP status code, or exceeds the
    # retry limit. Each retry waits for a multiple of the previous retry interval.
    for i in {1..15}; do
        probe_url &&
            return 0

        wait=$((i * 3))
        echo -e "# WARN: [${i}/15] Waiting for ${wait}s before retrying...\n"
        sleep ${wait}
    done
    return 1
}

if test_url; then
    echo "# SUCCESS: URL '${URL}' returned expected status code '${STATUS_CODE}'."
    exit 0
else
    echo "# ERROR: URL '${URL}' is not accessible or returned an" \
        "unexpected status code." >&2
    exit 1
fi
