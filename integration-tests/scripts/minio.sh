#!/bin/sh
# ROSA HCP workaround for Docker limits
# for namespaces 'minio-operator'
set -o errexit
set -o nounset
set -o pipefail

echo "[INFO] Applying minIO workaround"
DOCKER_IO_AUTH="$(cat /usr/local/rhtap-cli-install/docker_io)"
oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}' > ./global-pull-secret.json
oc get secret -n openshift-config -o yaml pull-secret > global-pull-secret.yaml
yq -i e 'del(.metadata.namespace)' global-pull-secret.yaml
oc registry login --registry=docker.io --auth-basic="$DOCKER_IO_AUTH" --to=./global-pull-secret.json

namespace_sa_names=$(cat << 'EOF'
minio-operator|minio-operator-e2e
EOF
)
while IFS='|' read -r ns sa_name; do
    oc create namespace "$ns" --dry-run=client -o yaml | oc apply -f -
    oc create sa "$sa_name" -n "$ns" --dry-run=client -o yaml | oc apply -f -
    oc apply -f global-pull-secret.yaml -n "$ns"
    oc set data secret/pull-secret -n "$ns" --from-file=.dockerconfigjson=./global-pull-secret.json
    oc secrets link "$sa_name" pull-secret --for=pull -n "$ns"
done <<< "$namespace_sa_names"
