#!/usr/bin/env bash
#
# Tests if the requested projects are available on the cluster.
#

shopt -s inherit_errexit
set -Eeu -o pipefail

# List of projects to test.
declare -r -a PROJECTS=("${@}")

# Tests if the projects are available on the cluster, returns true when all
# projects are found, or false on the first missing project.
projects_available() {
    for project in "${PROJECTS[@]}"; do
        echo "# Checking if project '${project}' is present on the cluster..."
        if (! oc get project "${project}"); then
            echo -en "#\n# [ERROR] Project '${project}' is not found!\n#\n"
            return 1
        fi
        echo "# Project '${project}' is installed!"
    done
    return 0
}

# Verifies the availability of the projects, retrying a few times.
test_projects() {
    if [[ ${#PROJECTS[@]} -eq 0 ]]; then
        echo "Usage: $0 <CRDS>"
        exit 1
    fi

    for i in {1..11}; do
        wait=$((i * 5))
        echo "### [${i}/5] Waiting for ${wait} seconds before retrying..."
        sleep ${wait}

        projects_available &&
            return 0
    done
    return 1
}

#
# Main
#

if test_projects; then
    echo "# Projects are available: '${PROJECTS[*]}'"
    exit 0
else
    echo "# ERROR: Projects not available!"
    exit 1
fi
