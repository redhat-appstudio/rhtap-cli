#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

echo "[INFO]Configuring deployment"

acs_install_enabled="${acs_install_enabled:-true}"
quay_install_enabled="${quay_install_enabled:-true}"
github_enabled="${github_enabled:-true}"
gitlab_enabled="${gitlab_enabled:-true}"
jenkins_enabled="${jenkins_enabled:-true}"

export DEVELOPER_HUB__CATALOG__URL GITHUB__APP__ID GITHUB__APP__CLIENT__ID GITHUB__APP__CLIENT__SECRET \
  GITHUB__APP__PRIVATE_KEY GITOPS__GIT_TOKEN GITHUB__APP__WEBHOOK__SECRET GITLAB__TOKEN JENKINS_API_TOKEN \
  JENKINS_URL JENKINS_USERNAME QUAY__DOCKERCONFIGJSON QUAY__API_TOKEN ACS__CENTRAL_ENDPOINT ACS__API_TOKEN

# Variables for RHTAP Sample Backstage Templates
DEVELOPER_HUB__CATALOG__URL="https://github.com/redhat-appstudio/tssc-sample-templates/blob/main/all.yaml"
# Variables for GitHub integration
GITHUB__APP__ID=$(cat /usr/local/rhtap-cli-install/rhdh-github-app-id)
GITHUB__APP__CLIENT__ID=$(cat /usr/local/rhtap-cli-install/rhdh-github-client-id)
GITHUB__APP__CLIENT__SECRET=$(cat /usr/local/rhtap-cli-install/rhdh-github-client-secret)
GITHUB__APP__PRIVATE_KEY=$(base64 -d < /usr/local/rhtap-cli-install/rhdh-github-private-key | sed 's/^/        /')
GITOPS__GIT_TOKEN=$(cat /usr/local/rhtap-cli-install/github_token)
GITHUB__APP__WEBHOOK__SECRET=$(cat /usr/local/rhtap-cli-install/rhdh-github-webhook-secret)
# Variables for Gitlab integration
GITLAB__TOKEN=$(cat /usr/local/rhtap-cli-install/gitlab_token)
# Variables for Jenkins integration
JENKINS_API_TOKEN=$(cat /usr/local/rhtap-cli-install/jenkins-api-token)
JENKINS_URL=$(cat /usr/local/rhtap-cli-install/jenkins-url)
JENKINS_USERNAME=$(cat /usr/local/rhtap-cli-install/jenkins-username)
## Variables for quay.io integration
QUAY__DOCKERCONFIGJSON=$(cat /usr/local/rhtap-cli-install/quay-dockerconfig-json)
QUAY__API_TOKEN=$(cat /usr/local/rhtap-cli-install/quay-api-token)
## Variables for ACS integration
ACS__CENTRAL_ENDPOINT=$(cat /usr/local/rhtap-cli-install/acs-central-endpoint)
ACS__API_TOKEN=$(cat /usr/local/rhtap-cli-install/acs-api-token)

tpl_file="installer/charts/values.yaml.tpl"
config_file="installer/config.yaml"

ci_enabled() {
  echo "[INFO] Turn ci to true, this is required when you perform rhtap-e2e automation test against RHTAP"
  sed -i'' -e 's/ci: false/ci: true/g' "$tpl_file"
}

update_dh_catalog_url() {
  # if DEVELOPER_HUB__CATALOG__URL is not empty string, then update the catalog url
  if [[ -n "${DEVELOPER_HUB__CATALOG__URL}" ]]; then
    echo "[INFO] Update dh catalog url with $DEVELOPER_HUB__CATALOG__URL"
    yq -i ".rhtapCLI.features.redHatDeveloperHub.properties.catalogURL = strenv(DEVELOPER_HUB__CATALOG__URL)" "${config_file}"
  fi
}

github_integration() {
  # if github_enabled is true, then perform the github integration
  if [[ "${github_enabled}" == "true" ]]; then
    echo "[INFO] Config Github integration with RHTAP"

    cat <<EOF >>"$tpl_file"
integrations:
  github:
    id: "${GITHUB__APP__ID}"
    clientId: "${GITHUB__APP__CLIENT__ID}"
    clientSecret: "${GITHUB__APP__CLIENT__SECRET}"
    host: "github.com"
    publicKey: |-
$(echo "${GITHUB__APP__PRIVATE_KEY}" | sed 's/^/      /')
    token: "${GITOPS__GIT_TOKEN}"
    webhookSecret: "${GITHUB__APP__WEBHOOK__SECRET}"
EOF
  fi
}

jenkins_integration() {
  if [[ "${jenkins_enabled}" == "true" ]]; then
    echo "[INFO] Integrates an exising Jenkins server into RHTAP"
    ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" jenkins --token="$JENKINS_API_TOKEN" --url="$JENKINS_URL" --username="$JENKINS_USERNAME" --force
  fi
}

gitlab_integration() {
  if [[ "${gitlab_enabled}" == "true" ]]; then
    echo "[INFO] Configure Gitlab integration into RHTAP"
    ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" gitlab --token "${GITLAB__TOKEN}"
  fi
}

quay_integration() {
  if [[ "${quay_install_enabled}" == "false" ]]; then
    echo "[INFO] Configure quay.io integration into RHTAP"
    ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" quay --url="https://quay.io" --dockerconfigjson="${QUAY__DOCKERCONFIGJSON}" --token="${QUAY__API_TOKEN}"
  fi

}

acs_integration() {
  if [[ "${acs_install_enabled}" == "false" ]]; then
    echo "[INFO] Configure an existing intance of ACS integration into RHTAP"
    ./bin/rhtap-cli integration --kube-config "$KUBECONFIG" acs --endpoint="${ACS__CENTRAL_ENDPOINT}" --token="${ACS__API_TOKEN}"
  fi
}

acs_quay_connection() {
  # if quay_install_enabled is false, then skip the quay integration
  if [[ "${quay_install_enabled}" == "true" ]]; then
    echo "[INFO] Configure internal Quay integration with internal ACS"

    acs_central_url=https://$(kubectl -n rhtap-acs get route central -o  'jsonpath={.spec.host}')
    acs_central_password=$(kubectl -n rhtap-acs get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}')
    quay_host=$(kubectl -n rhtap-quay get route rhtap-quay-quay -o  'jsonpath={.spec.host}')
    quay_username=$(kubectl -n rhtap-quay get secret rhtap-quay-super-user -o go-template='{{index .data "username" | base64decode}}')
    quay_password=$(kubectl -n rhtap-quay get secret rhtap-quay-super-user -o go-template='{{index .data "password" | base64decode}}')

    curl -k --silent \
      -X POST \
      -d  '{"id":"","name":"rhtap-quay","categories":["REGISTRY"],"quay":{"endpoint":"'"${quay_host}"'","oauthToken":"","insecure":false,"registryRobotCredentials":{"username":"'"${quay_username}"'","password":"'"${quay_password}"'"}},"autogenerated":false,"clusterId":"","skipTestIntegration":true,"type":"quay"}' \
      -u admin:"$acs_central_password" \
      "$acs_central_url/v1/imageintegrations"
  fi
}

install_rhtap() {
  echo "[INFO] Start installing RHTAP"
  github_integration
  echo "[INFO] Building binary"
  make build

  echo "[INFO] Installing RHTAP"
  jenkins_integration
  gitlab_integration
  quay_integration
  acs_integration
  # for debugging purpose
  echo "installer/charts/values.yaml.tpl============"
  cat "$tpl_file"
  ./bin/rhtap-cli deploy --timeout 30m --embedded false --config "$config_file" --values-template "$tpl_file" --kube-config "$KUBECONFIG" --debug --log-level=debug

  homepage_url=https://$(kubectl -n rhtap get route backstage-developer-hub -o  'jsonpath={.spec.host}')
  callback_url=https://$(kubectl -n rhtap get route backstage-developer-hub -o  'jsonpath={.spec.host}')/api/auth/github/handler/frame
  webhook_url=https://$(kubectl -n openshift-pipelines get route pipelines-as-code-controller -o 'jsonpath={.spec.host}')

  quay_host=$(kubectl -n rhtap-quay get route rhtap-quay-quay -o  'jsonpath={.spec.host}')
  quay_username=$(kubectl -n rhtap-quay get secret rhtap-quay-super-user -o go-template='{{index .data "username" | base64decode}}')
  quay_password=$(kubectl -n rhtap-quay get secret rhtap-quay-super-user -o go-template='{{index .data "password" | base64decode}}')
  echo "[INFO]homepage_url=$homepage_url"
  echo "[INFO]callback_url=$callback_url"
  echo "[INFO]webhook_url=$webhook_url"
}

ci_enabled
update_dh_catalog_url
install_rhtap
acs_quay_connection