{{- $crc := required "CRC settings" .Installer.Settings.crc -}}
{{- $tas := required "TAS settings" .Installer.Products.Trusted_Artifact_Signer -}}
{{- $tpa := required "TPA settings" .Installer.Products.Trusted_Profile_Analyzer -}}
{{- $keycloak := required "Keycloak settings" .Installer.Products.Keycloak -}}
{{- $acs := required "Red Hat ACS settings" .Installer.Products.Advanced_Cluster_Security -}}
{{- $gitops := required "GitOps settings" .Installer.Products.OpenShift_GitOps -}}
{{- $pipelines := required "Pipelines settings" .Installer.Products.OpenShift_Pipelines -}}
{{- $pipelinesNamespace := "openshift-pipelines" -}}
{{- $rhdh := required "RHDH settings" .Installer.Products.Developer_Hub -}}
{{- $ingressDomain := required "OpenShift ingress domain" .OpenShift.Ingress.Domain -}}
{{- $ingressRouterCA := required "OpenShift RouterCA" .OpenShift.Ingress.RouterCA -}}
{{- $openshiftMinorVersion := required "OpenShift Version" .OpenShift.MinorVersion -}}
---
debug:
  ci: {{ dig "ci" "debug" false .Installer.Settings }}

#
# tssc-openshift
#

openshift:
  projects:
{{- if $keycloak.Enabled }}
    - {{ $keycloak.Namespace }}
    {{- if $keycloak.Properties.manageSubscription }}
    - rhbk-operator
    {{- end }}
{{- end }}
{{- if $acs.Enabled }}
    - {{ $acs.Namespace }}
    {{- if $acs.Properties.manageSubscription }}
    - rhacs-operator
    {{- end }}
{{- end }}
{{- if $gitops.Enabled }}
    - {{ $gitops.Namespace }}
{{- end }}
{{- if $tas.Enabled }}
    - {{ $tas.Namespace }}
{{- end }}
{{- if $tpa.Enabled }}
    - {{ $tpa.Namespace }}
{{- end }}
{{- if $rhdh.Enabled }}
    - {{ $rhdh.Namespace }}
{{- end }}

#
# tssc-subscriptions
#


subscriptions:
  crunchyData:
    enabled: {{ or $tpa.Enabled $rhdh.Enabled }}
    managed: {{ or (and $tpa.Enabled $tpa.Properties.manageSubscription ) (and $rhdh.Enabled $rhdh.Properties.manageSubscription) }}
  openshiftGitOps:
    enabled: {{ $gitops.Enabled }}
    managed: {{ and $gitops.Enabled $gitops.Properties.manageSubscription }}
    config:
      argoCDClusterNamespace: {{ $gitops.Namespace }}
  openshiftKeycloak:
    enabled: {{ $keycloak.Enabled }}
    managed: {{ and $keycloak.Enabled $keycloak.Properties.manageSubscription }}
    operatorGroup:
      targetNamespaces:
        - {{ default "empty" $keycloak.Namespace }}
  openshiftPipelines:
    enabled: {{ $pipelines.Enabled }}
    managed: {{ and $pipelines.Enabled $pipelines.Properties.manageSubscription }}
  openshiftTrustedArtifactSigner:
    enabled: {{ $tas.Enabled }}
    managed: {{ and $tas.Enabled $tas.Properties.manageSubscription }}
  advancedClusterSecurity:
    enabled: {{ $acs.Enabled }}
    managed: {{ and $acs.Enabled $acs.Properties.manageSubscription }}
  developerHub:
    enabled: {{ $rhdh.Enabled }}
    managed: {{ and $rhdh.Enabled $rhdh.Properties.manageSubscription }}

#
# tssc-infrastructure
#

infrastructure:
  developerHub:
    namespace: {{ $rhdh.Namespace }}
  postgresClusters:
    keycloak:
      enabled: {{ $keycloak.Enabled }}
      namespace: {{ $keycloak.Namespace }}
    tpa:
      enabled: {{ $tpa.Enabled }}
      namespace: {{ $tpa.Namespace }}
  openShiftPipelines:
    enabled: {{ $pipelines.Enabled }}
    namespace: {{ $pipelinesNamespace }}

#
# tssc-backing-services
#

{{- $keycloakRouteTLSSecretName := "keycloak-tls" }}
{{- $keycloakRouteHost := printf "sso.%s" $ingressDomain }}
{{- $argoCDName := printf "%s-gitops" .Installer.Namespace }}

backingServices:
  keycloak:
    enabled: {{ $keycloak.Enabled }}
    namespace: {{ $keycloak.Namespace }}
    instances: 1
    database:
      host: keycloak-primary
      name: keycloak
      secretName: keycloak-pguser-keycloak
    route:
      host: {{ $keycloakRouteHost }}
      tls:
        enabled: {{ not $crc }}
        secretName: {{ $keycloakRouteTLSSecretName }}
        termination: reencrypt
{{- if $crc }}
      annotations:
        route.openshift.io/termination: reencrypt
{{- end }}
    service:
      annotations:
        service.beta.openshift.io/serving-cert-secret-name: {{ $keycloakRouteTLSSecretName }}
  argoCD:
    enabled: {{ $gitops.Enabled }}
    name: {{ $argoCDName }}
    namespace: {{ $gitops.Namespace }}
    integrationSecret:
      namespace: {{ .Installer.Namespace }}
    ingressDomain: {{ $ingressDomain }}

#
# tssc-acs
#

acs: &acs
  enabled: {{ $acs.Enabled }}
  name: &acsName stackrox-central-services
  ingressDomain: {{ $ingressDomain }}
  ingressRouterCA: {{ $ingressRouterCA }}
  integrationSecret:
    namespace: {{ .Installer.Namespace }}
  test:
    scanner:
      image: registry.access.redhat.com/ubi9:latest
  tssc:
    namespace: {{ .Installer.Namespace }}
acsTest: *acs

#
# tssc-app-namespaces
#
appNamespaces:
  argoCD:
    name: {{ $argoCDName }}
  namespace_prefixes:
  {{- range ($rhdh.Properties.namespacePrefixes | default (tuple (printf "%s-app" .Installer.Namespace))) }}
    - {{ . }}
  {{- end }}

#
# tssc-gitops
#

argoCD:
  enabled: {{ $rhdh.Enabled }}
  name: {{ $argoCDName }}
  namespace: {{ $gitops.Namespace }}
  integrationSecret:
    name: tssc-argocd-integration
    namespace: {{ .Installer.Namespace }}
  ingressDomain: {{ $ingressDomain }}
  tssc:
    namespace: {{ .Installer.Namespace }}

#
# tssc-pipelines
#

pipelines:
  namespace: {{ $pipelinesNamespace }}
  tssc:
    namespace: {{ .Installer.Namespace }}

#
# tssc-integrations
#

integrations:
  acs:
    enabled: {{ $acs.Enabled }}
  argoCD:
    enabled: {{ $gitops.Enabled }}
    namespace: {{ $gitops.Namespace }}
  tssc:
    namespace: {{ .Installer.Namespace }}
#   github:
#     clientId: ""
#     clientSecret: ""
#     id: ""
#     host: "github.com"
#     publicKey: |
#       -----BEGIN RSA PRIVATE KEY-----   # notsecret
#       -----END RSA PRIVATE KEY-----     # notsecret
#     token: ""
#     webhookSecret: ""
#   gitlab:
#     token: ""

#
# tssc-dh
#

{{- $catalogURL := required "Red Hat Developer Hub Catalog URL is required"
    $rhdh.Properties.catalogURL }}

{{- $authProvider := required "Auth Provider is required"
    $rhdh.Properties.authProvider }}


developerHub:
  namespace: {{ $rhdh.Namespace }}
  ingressDomain: {{ $ingressDomain }}
  catalogURL: {{ $catalogURL }}
  authProvider: {{ $authProvider }}
  integrationSecrets:
    namespace: {{ .Installer.Namespace }}
  RBAC:
    enabled: {{ dig "Properties" "RBAC" "enabled" false $rhdh }}
{{- if eq $authProvider "github" }}
    adminUsers:
{{ dig "Properties" "RBAC" "adminUsers" (list "${GITHUB__USERNAME}") $rhdh | toYaml | indent 6 }}
    orgs:
{{ dig "Properties" "RBAC" "orgs" (list "${GITHUB__ORG}") $rhdh | toYaml | indent 6 }}
{{- else if eq $authProvider "gitlab" }}
    adminUsers:
{{ dig "Properties" "RBAC" "adminUsers" (list "${GITLAB__USERNAME}") $rhdh | toYaml | indent 6 }}
{{- end }}

#
# tssc-tpa-realm
#

{{- $tpaAppDomain := printf "-%s.%s" $tpa.Namespace $ingressDomain }}
{{- $tpaOIDCClientsSecretName := "tpa-realm-chicken-clients" }}
{{- $tpaTestingUsersEnabled := false }}
{{- $protocol := "https" -}}
{{- if $crc }}
  {{- $protocol = "http" }}
{{- end }}
{{- $tpaRealmPath := "realms/chicken" }}
{{- $tpaOIDCIssuerURL := printf "%s://%s/%s" $protocol $keycloakRouteHost $tpaRealmPath }}

trustedProfileAnalyzerRealm:
  enabled: {{ $keycloak.Enabled }}
  appDomain: "{{ $tpaAppDomain }}"
  keycloakCR:
    namespace: {{ $keycloak.Namespace }}
    name: keycloak
  oidcIssuerURL: {{ $tpaOIDCIssuerURL }}
  oidcClientsSecretName: {{ $tpaOIDCClientsSecretName }}
  clients:
    cli:
      enabled: true
    testingManager:
      enabled: {{ $tpaTestingUsersEnabled }}
    testingUser:
      enabled: {{ $tpaTestingUsersEnabled }}
  frontendRedirectUris:
    - "http://localhost:8080"
{{- range list "server" "sbom" }}
    - "{{ printf "%s://%s-%s.%s" $protocol . $tpa.Namespace $ingressDomain }}"
    - "{{ printf "%s://%s-%s.%s/*" $protocol . $tpa.Namespace $ingressDomain }}"
{{- end }}
  integrationSecret:
    bombasticAPI: {{
      printf "%s://server-%s.%s"
        $protocol
        $tpa.Namespace
        $ingressDomain
    }}
    namespace: {{ .Installer.Namespace }}
    name: tssc-trustification-integration

#
# tssc-tpa
#

{{- $tpaDatabaseSecretName := "tpa-pguser-tpa" }}

trustedProfileAnalyzer:
  enabled: {{ $tpa.Enabled }}
  oidcIssuerURL: {{ $tpaOIDCIssuerURL }}

redhat-trusted-profile-analyzer:
  appDomain: "{{ $tpaAppDomain }}"
  ingress: &tpaIngress
    className: openshift-default
  openshift: &tpaOpenShift
    # In practice it toggles "https" vs. "http" for TPA components, for CRC it's
    # easier to focus on "http" communication only.
    useServiceCa: {{ not $crc }}
  database: &tpaDatabase
    name:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName }}
          key: dbname
    host:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName }}
          key: host
    port:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName}}
          key: port
    username:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName }}
          key: user
    password:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaDatabaseSecretName }}
          key: password
  createDatabase: *tpaDatabase
  migrateDatabase: *tpaDatabase
  storage: &tpaStorage
    type: filesystem
    size: 32Gi
  oidc: &tpaOIDC
    issuerUrl: {{ $tpaOIDCIssuerURL }}
    clients:
      cli:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: cli
{{- if $tpaTestingUsersEnabled }}
      testingUser:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: testingUser
      testingManager:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: testingManager
{{- end }}

trustification:
  appDomain: "{{ $tpaAppDomain }}"
  openshift: *tpaOpenShift
  storage: *tpaStorage
  oidc: *tpaOIDC
  ingress: *tpaIngress
  tls:
    serviceEnabled: "{{ not $crc }}"

#
# tssc-tas
#

{{- $tasRealmPath := "realms/trusted-artifact-signer" }}

trustedArtifactSigner:
  enabled: {{ $tas.Enabled }}
  ingressDomain: "{{ $ingressDomain }}"
  keycloakRealmImport:
    enabled: {{ $keycloak.Enabled }}
    keycloakCR:
      namespace: {{ $keycloak.Namespace }}
      name: keycloak
  secureSign:
    enabled: {{ $tas.Enabled }}
    namespace: {{ $tas.Namespace }}
    fulcio:
      oidc:
        clientID: trusted-artifact-signer
{{- if $crc }}
        issuerURL: {{ printf "http://%s/%s" $keycloakRouteHost $tasRealmPath }}
{{- else }}
        issuerURL: {{ printf "https://%s/%s" $keycloakRouteHost $tasRealmPath }}
{{- end }}
      certificate:
        # TODO: promopt the user for organization email/name input!
        organizationEmail: trusted-artifact-signer@company.dev
        organizationName: TSSC
  integrationSecret:
    namespace: {{ .Installer.Namespace }}
