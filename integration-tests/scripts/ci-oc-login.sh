#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

## Script to be used in CI only. 

# Login to OpenShift
export KUBECONFIG=$HOME/rhtap-cli-ci-kubeconfig
echo "[INFO]Logging into openshift cluster"

$OCP_LOGIN_COMMAND >/dev/null
echo "[INFO]Console: $(kubectl get routes -n openshift-console console -o jsonpath='{.spec.port.targetPort}://{.spec.host}')"