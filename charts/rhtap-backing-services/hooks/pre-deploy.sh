#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

make_helm_managed() {
    KIND="$1"
    NAMESPACE="$2"
    NAME="$3"

    echo -n "."
    kubectl annotate "$KIND" "$NAME" meta.helm.sh/release-name=rhtap-backing-services >/dev/null
    echo -n "."
    kubectl annotate "$KIND" "$NAME" meta.helm.sh/release-namespace="$NAMESPACE" >/dev/null
    echo -n "."
    kubectl label "$KIND" "$NAME" app.kubernetes.io/managed-by=Helm >/dev/null
}

openshift_pipelines() {
    ### Workaround
    ### OpenShift Pipelines cannot be configured before the operator is deployed,
    ### as it is creating the TektonConfig resource, which default content cannot
    ### be modified at install time.
    # Allow the TektonConfig resource to be managed by Helm
    echo -n "* Configuring OpenShift Pipelines: "
    make_helm_managed "TektonConfig" "rhtap" "config"
    echo "OK"

    ### Workaround
    ### OpenShift Pipelines cannot be configured to generate the signing secret
    ### at deployment time.
    echo -n "* Configuring Chains secret: "
    NAMESPACE="openshift-pipelines"
    SECRET="signing-secrets"
    if [ "$(kubectl get secret -n "$NAMESPACE" "$SECRET" -o jsonpath='{.data}' --ignore-not-found --allow-missing-template-keys)" == "" ]; then
        # Delete the empty secret/signing-secrets
        echo -n "."
        kubectl delete secrets  -n "$NAMESPACE" "$SECRET" --ignore-not-found=true >/dev/null

        # To run without user input, generate a password
        echo -n "."
        COSIGN_PASSWORD=$( openssl rand -base64 30 )
        export COSIGN_PASSWORD

        # Generate the key pair secret directly in the cluster.
        # The secret will be created as immutable.
        echo -n "."
        cosign generate-key-pair "k8s://$NAMESPACE/$SECRET" >/dev/null 2>&1
        rm cosign.pub
    fi
    echo "OK"
}

#
# Main
#
main() {
    openshift_pipelines
}

main
