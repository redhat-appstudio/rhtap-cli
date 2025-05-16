#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

## This file should be present only in CI created by integration-tests/scripts/ci-oc-login.sh
if [ -f "$HOME/rhtap-cli-ci-kubeconfig" ]; then
    export KUBECONFIG="$HOME/rhtap-cli-ci-kubeconfig"
fi

echo "[INFO]Configuring deployment"
acs_config="${acs_config:-new}" # new, hosted
tpa_config="${tpa_config:-new}" # new, hosted
registry_config="${registry_config:-quay}" # quay, quay.io, artifactory, nexus
scm_config="${scm_config:-github}"  # github, gitlab, bitbucket
pipeline_config="${pipeline_config:-tekton}" # tekton, jenkins
auth_config="${auth_config:-github}" # github, gitlab

echo "[INFO] acs_config=$acs_config"
echo "[INFO] tpa_config=$tpa_config"
echo "[INFO] registry_config=$registry_config"
echo "[INFO] scm_config=$scm_config"
echo "[INFO] pipeline_config=$pipeline_config"
echo "[INFO] auth_config=$auth_config"

tpl_file="installer/charts/values.yaml.tpl"
config_file="installer/config.yaml"

ci_enabled() {
  echo "[INFO] Turn ci to true, this is required when you perform rhtap-e2e automation test against TSSC"
  sed -i'' -e 's/ci: false/ci: true/g' "$tpl_file"
}

update_dh_catalog_url() {
  # if DEVELOPER_HUB__CATALOG__URL is not empty string, then update the catalog url
  if [[ -n "${DEVELOPER_HUB__CATALOG__URL}" ]]; then
    echo "[INFO] Update dh catalog url with $DEVELOPER_HUB__CATALOG__URL"
    yq -i ".tssc.products.redHatDeveloperHub.properties.catalogURL = strenv(DEVELOPER_HUB__CATALOG__URL)" "${config_file}"
  fi
}

# Workaround: This function has to be called before tssc import "installer/config.yaml" into cluster.
# Currently, the tssc `config` subcommand lacks the ability to modify property values stored in config.yaml.
github_integration() {
  # if scm_config is "github", then perform the github integration
  if [[ "${scm_config}" == "github" || "$auth_config" == "github" ]]; then
    echo "[INFO] Config Github integration with TSSC"

    GITHUB__APP__ID="${GITHUB__APP__ID:-$(cat /usr/local/rhtap-cli-install/rhdh-github-app-id)}"
    GITHUB__APP__CLIENT__ID="${GITHUB__APP__CLIENT__ID:-$(cat /usr/local/rhtap-cli-install/rhdh-github-client-id)}"
    GITHUB__APP__CLIENT__SECRET="${GITHUB__APP__CLIENT__SECRET:-$(cat /usr/local/rhtap-cli-install/rhdh-github-client-secret)}"
    GITHUB__APP__PRIVATE_KEY="${GITHUB__APP__PRIVATE_KEY:-$(base64 -d < /usr/local/rhtap-cli-install/rhdh-github-private-key | sed 's/^/        /')}"
    GITOPS__GIT_TOKEN="${GITOPS__GIT_TOKEN:-$(cat /usr/local/rhtap-cli-install/github_token)}"
    GITHUB__APP__WEBHOOK__SECRET="${GITHUB__APP__WEBHOOK__SECRET:-$(cat /usr/local/rhtap-cli-install/rhdh-github-webhook-secret)}"

    cat <<EOF >>"$tpl_file"
integrations:
  github:
    id: "${GITHUB__APP__ID}"
    clientId: "${GITHUB__APP__CLIENT__ID}"
    clientSecret: "${GITHUB__APP__CLIENT__SECRET}"
    host: "github.com"
    publicKey: |-
$(printf "%s\n" "${GITHUB__APP__PRIVATE_KEY}" | sed 's/^/      /')
    token: "${GITOPS__GIT_TOKEN}"
    webhookSecret: "${GITHUB__APP__WEBHOOK__SECRET}"
EOF
  fi
}

jenkins_integration() {
  if [[ "${pipeline_config}" == "jenkins" ]]; then
    echo "[INFO] Integrates an exising Jenkins server into TSSC"

    JENKINS_API_TOKEN="${JENKINS_API_TOKEN:-$(cat /usr/local/rhtap-cli-install/jenkins-api-token)}"
    JENKINS_URL="${JENKINS_URL:-$(cat /usr/local/rhtap-cli-install/jenkins-url)}"
    JENKINS_USERNAME="${JENKINS_USERNAME:-$(cat /usr/local/rhtap-cli-install/jenkins-username)}"

    ./bin/tssc integration --kube-config "$KUBECONFIG" jenkins --token="$JENKINS_API_TOKEN" --url="$JENKINS_URL" --username="$JENKINS_USERNAME" --force
  fi
}

gitlab_integration() {
  if [[ "${scm_config}" == "gitlab" || "$auth_config" = "gitlab" ]]; then
    echo "[INFO] Configure Gitlab integration into TSSC"

    GITLAB__TOKEN="${GITLAB__TOKEN:-$(cat /usr/local/rhtap-cli-install/gitlab_token)}"

    GITLAB__APP__ID="${GITLAB__APP__ID:-$(cat /usr/local/rhtap-cli-install/gitlab-app-id)}"
    GITLAB__APP_SECRET="${GITLAB__APP_SECRET:-$(cat /usr/local/rhtap-cli-install/gitlab-app-secret)}"
    GITLAB__GROUP="${GITLAB__GROUP:-$(cat /usr/local/rhtap-cli-install/gitlab-group)}"

    ./bin/tssc integration --kube-config "$KUBECONFIG" gitlab --token="${GITLAB__TOKEN}" --app-id="${GITLAB__APP__ID}" --app-secret="${GITLAB__APP_SECRET}" --group="${GITLAB__GROUP}"
  fi
}

# Workaround: This function has to be called before tssc import "installer/config.yaml" into cluster.
# Currently, the tssc `config` subcommand lacks the ability to modify property values stored in cluster
disable_quay() {
  # if registry_config is not "quay", then disable Quay installation
  if [[ "${registry_config}" != "quay" ]]; then
  
    echo "[INFO] Disable Quay installation"
    yq e '.tssc.products.redHatQuay.enabled = false' -i "${config_file}"
  fi
}

quayio_integration() {
  if [[ "${registry_config}" == "quay.io" ]]; then
    echo "[INFO] Configure quay.io integration into TSSC"

    QUAY__DOCKERCONFIGJSON="${QUAY__DOCKERCONFIGJSON:-$(cat /usr/local/rhtap-cli-install/quay-dockerconfig-json)}"
    QUAY__API_TOKEN="${QUAY__API_TOKEN:-$(cat /usr/local/rhtap-cli-install/quay-api-token)}"

    ./bin/tssc integration --kube-config "$KUBECONFIG" quay --url="https://quay.io" --dockerconfigjson="${QUAY__DOCKERCONFIGJSON}" --token="${QUAY__API_TOKEN}"
  fi

}

# Workaround: This function has to be called before tssc import "installer/config.yaml" into cluster.
# Currently, the tssc `config` subcommand lacks the ability to modify property values stored in cluster
disable_acs() {
  if [[ "${acs_config}" == "hosted" ]]; then
    echo "[INFO] Disable ACS installation"
    yq e '.tssc.products.redHatAdvancedClusterSecurity.enabled = false' -i "${config_file}"
  fi
}

acs_integration() {
  if [[ "${acs_config}" == "hosted" ]]; then
    echo "[INFO] Configure an existing intance of ACS integration into TSSC"

    ACS__CENTRAL_ENDPOINT="${ACS__CENTRAL_ENDPOINT:-$(cat /usr/local/rhtap-cli-install/acs-central-endpoint)}"
    ACS__API_TOKEN="${ACS__API_TOKEN:-$(cat /usr/local/rhtap-cli-install/acs-api-token)}"

    ./bin/tssc integration --kube-config "$KUBECONFIG" acs --endpoint="${ACS__CENTRAL_ENDPOINT}" --token="${ACS__API_TOKEN}"
  fi
}

bitbucket_integration() {
  if [[ "${scm_config}" == "bitbucket" ]]; then
    echo "[INFO] Configure Bitbucket integration into TSSC"

    BITBUCKET_USERNAME="${BITBUCKET_USERNAME:-$(cat /usr/local/rhtap-cli-install/bitbucket-username)}"
    BITBUCKET_APP_PASSWORD="${BITBUCKET_APP_PASSWORD:-$(cat /usr/local/rhtap-cli-install/bitbucket-app-password)}"

    ./bin/tssc integration --kube-config "$KUBECONFIG" bitbucket --host="${BITBUCKET_HOST}" --username="${BITBUCKET_USERNAME}" --app-password="${BITBUCKET_APP_PASSWORD}"
  fi
}

# Workaround: This function has to be called before tssc import "installer/config.yaml" into cluster.
# Currently, the tssc `config` subcommand lacks the ability to modify property values stored in cluster
disable_tpa() {
  if [[ "${tpa_config}" == "hosted" ]]; then
    echo "[INFO] Disable TPA installation"
    yq e '.tssc.products.trustedProfileAnalyzer.enabled = false' -i "${config_file}"
  fi
}

tpa_integration() {
  if [[ "${tpa_config}" == "hosted" ]]; then
    echo "[INFO] Configure a hosted TPA integration into TSSC"

    BOMBASTIC_API_URL="${BOMBASTIC_API_URL:-$(cat /usr/local/rhtap-cli-install/bombastic-api-url)}"
    OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-$(cat /usr/local/rhtap-cli-install/oidc-client-id)}"
    OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-$(cat /usr/local/rhtap-cli-install/oidc-client-secret)}"
    OIDC_ISSUER_URL="${OIDC_ISSUER_URL:-$(cat /usr/local/rhtap-cli-install/oidc-issuer-url)}"

    ./bin/tssc integration --kube-config "$KUBECONFIG" trustification --bombastic-api-url="${BOMBASTIC_API_URL}" --oidc-client-id="${OIDC_CLIENT_ID}" --oidc-client-secret="${OIDC_CLIENT_SECRET}" --oidc-issuer-url="${OIDC_ISSUER_URL}" --supported-cyclonedx-version="${SUPPORTED_CYCLONEDX_VERSION}"
  fi
}

artifactory_integration() {
  if [[ "${registry_config}" == "artifactory" ]]; then
    echo "[INFO] Configure Artifactory integration into TSSC"

    ARTIFACTORY_URL="${ARTIFACTORY_URL:-$(cat /usr/local/rhtap-cli-install/artifactory-url)}"
    ARTIFACTORY_TOKEN="${ARTIFACTORY_TOKEN:-$(cat /usr/local/rhtap-cli-install/artifactory-token)}"
    ARTIFACTORY_DOCKERCONFIGJSON="${ARTIFACTORY_DOCKERCONFIGJSON:-$(cat /usr/local/rhtap-cli-install/artifactory-dockerconfig-json)}"
    ./bin/tssc integration --kube-config "$KUBECONFIG" artifactory --url="${ARTIFACTORY_URL}" --token="${ARTIFACTORY_TOKEN} " --dockerconfigjson="${ARTIFACTORY_DOCKERCONFIGJSON}"
  fi
}

nexus_integration() {
  if [[ "${registry_config}" == "nexus" ]]; then
    echo "[INFO] Configure Nexus integration into TSSC"

    NEXUS_URL="${NEXUS_URL:-$(cat /usr/local/rhtap-cli-install/nexus-ui-url)}"
    NEXUS_DOCKERCONFIGJSON="${NEXUS_DOCKERCONFIGJSON:-$(cat /usr/local/rhtap-cli-install/nexus-dockerconfig-json)}"
    ./bin/tssc integration --kube-config "$KUBECONFIG" nexus --url="${NEXUS_URL}" --dockerconfigjson="${NEXUS_DOCKERCONFIGJSON}"
  fi
}

install_tssc() {
  echo "[INFO] Start installing TSSC"
  echo "[INFO] Building binary"
  make build

  echo "[INFO] Installing TSSC"

  echo "[INFO] Showing the local configuration"
  set -x
  cat "$config_file"
  set +x

  echo "[INFO] Applying the cluster configuration, and showing the 'config.yaml'"
  set -x
  ./bin/tssc config --kube-config "$KUBECONFIG" --get --create "$config_file"
  set +x

  echo "[INFO] Print out the content of 'values.yaml.tpl'"
  set -x
  cat "$tpl_file"
  set +x

  jenkins_integration
  tpa_integration
  acs_integration
  github_integration
  gitlab_integration
  bitbucket_integration
  quayio_integration
  artifactory_integration
  nexus_integration

  echo "[INFO] Running 'tssc deploy' command..."
  set -x
  ./bin/tssc deploy --timeout 35m --values-template "$tpl_file" --kube-config "$KUBECONFIG"
  set +x

  homepage_url=https://$(kubectl -n tssc-dh get route backstage-developer-hub -o  'jsonpath={.spec.host}')
  callback_url=https://$(kubectl -n tssc-dh get route backstage-developer-hub -o  'jsonpath={.spec.host}')/api/auth/${auth_config}/handler/frame
  webhook_url=https://$(kubectl -n openshift-pipelines get route pipelines-as-code-controller -o 'jsonpath={.spec.host}')

  echo "[INFO] homepage_url=$homepage_url"
  echo "[INFO] callback_url=$callback_url"
  echo "[INFO] webhook_url=$webhook_url"

}

ci_enabled
update_dh_catalog_url
disable_quay
disable_acs
disable_tpa
install_tssc
