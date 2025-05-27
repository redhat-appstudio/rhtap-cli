{{- $crc := required "CRC settings" .Installer.Products.crc -}}
{{- $tas := required "TAS settings" .Installer.Products.trustedArtifactSigner -}}
{{- $tpa := required "TPA settings" .Installer.Products.trustedProfileAnalyzer -}}
{{- $keycloak := required "Keycloak settings" .Installer.Products.keycloak -}}
{{- $acs := required "Red Hat ACS settings" .Installer.Products.advancedClusterSecurity -}}
{{- $gitops := required "GitOps settings" .Installer.Products.openShiftGitOps -}}
{{- $pipelines := required "Pipelines settings" .Installer.Products.openShiftPipelines -}}
{{- $quay := required "Quay settings" .Installer.Products.quay -}}
{{- $rhdh := required "RHDH settings" .Installer.Products.developerHub -}}
{{- $ingressDomain := required "OpenShift ingress domain" .OpenShift.Ingress.Domain -}}
{{- $ingressRouterCA := required "OpenShift RouterCA" .OpenShift.Ingress.RouterCA -}}
{{- $openshiftMinorVersion := required "OpenShift Version" .OpenShift.MinorVersion -}}
{{- $minIOOperatorEnabled := or $tpa.Enabled $quay.Enabled -}}
{{- $odfEnabled := or $tpa.Enabled $quay.Enabled -}}
{{- $odfNamespace := "openshift-storage" -}}
---
debug:
  ci: false

#
# tssc-openshift
#

openshift:
  projects:
{{- if $keycloak.Enabled }}
    - {{ $keycloak.Namespace }}
    {{- if $gitops.Properties.manageSubscription }}
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
{{- if $quay.Enabled }}
    - {{ $quay.Namespace }}
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
{{- if $odfEnabled }}
    - {{ $odfNamespace }}
{{- end }}
    - minio-operator

#
# tssc-subscriptions
#

{{- $odfChannel := printf "stable-%s" $openshiftMinorVersion }}

subscriptions:
  amqStreams:
    enabled: {{ $tpa.Enabled }}
    managed: {{ and $tpa.Enabled $tpa.Properties.manageSubscription }}
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
  quay:
    enabled: {{ $quay.Enabled }}
    managed: {{ and $quay.Enabled $quay.Properties.manageSubscription }}
  openShiftDataFoundation:
    enabled: {{ $odfEnabled }}
    managed: {{ $odfEnabled }}
    namespace: {{ $odfNamespace }}
    channel: {{ $odfChannel }}
    operatorGroup:
      targetNamespaces:
        - {{ $odfNamespace }}

#
# tssc-minio-operator
#

minIOOperator:
  enabled: {{ $minIOOperatorEnabled }}


#
# tssc-infrastructure
#

{{- $tpaKafkaSecretName := "tpa-kafka" }}
{{- $tpaKafkaBootstrapServers := "tpa-kafka-bootstrap:9092" }}
{{- $tpaMinIORootSecretName := "tpa-minio-root-env" }}

infrastructure:
  developerHub:
    namespace: {{ $rhdh.Namespace }}
  kafkas:
    tpa:
      enabled: {{ $tpa.Enabled }}
      namespace: {{ $tpa.Namespace }}
      username: {{ $tpaKafkaSecretName }}
  minIOTenants:
    tpa:
      enabled: {{ $tpa.Enabled }}
      namespace: {{ $tpa.Namespace }}
      rootSecretName: {{ $tpaMinIORootSecretName }}
      kafkaNotify:
        bootstrapServers: {{ $tpaKafkaBootstrapServers }}
        username: {{ $tpaKafkaSecretName }}
        password:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaKafkaSecretName }}
              key: password
  postgresClusters:
    keycloak:
      enabled: {{ $keycloak.Enabled }}
      namespace: {{ $keycloak.Namespace }}
    guac:
      enabled: {{ $tpa.Enabled }}
      namespace: {{ $tpa.Namespace }}
  openShiftPipelines:
    enabled: {{ $pipelines.Enabled }}
    namespace: {{ $pipelines.Namespace }}
  odf:
    enabled: {{ $odfEnabled }}
    backingStorageSize: 100Gi
    backingStoreName: noobaa-pv-backing-store
    namespace: {{ $odfNamespace }}

#
# tssc-backing-services
#

{{- $keycloakRouteTLSSecretName := "keycloak-tls" }}
{{- $keycloakRouteHost := printf "sso.%s" $ingressDomain }}
{{- $argoCDName := printf "%s-gitops" .Installer.Namespace }}
{{- $quayMinIOHost := printf "minio-%s.%s" $quay.Namespace $ingressDomain }}

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
        enabled: {{ not $crc.Enabled }}
        secretName: {{ $keycloakRouteTLSSecretName }}
        termination: reencrypt
{{- if $crc.Enabled }}
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

#
# tssc-pipelines
#

pipelines:
  namespace: {{ $pipelines.Namespace }}

#
# tssc-quay
#

quay:
  enabled: {{ $quay.Enabled }}
  namespace: {{ $quay.Namespace }}
  ingressDomain: {{ $ingressDomain }}
  ingressRouterCA: {{ $ingressRouterCA }}
  organization:
    email: {{ printf "tssc@%s" $ingressDomain }}
  secret:
    namespace: {{ .Installer.Namespace }}
    name: tssc-quay-integration
  config:
    superUser:
      email: {{ printf "admin@%s" $ingressDomain }}
  replicas:
    quay: 1
    clair: 1

#
# tssc-integrations
#

integrations:
  acs:
    enabled: {{ $acs.Enabled }}
  argoCD:
    enabled: {{ $gitops.Enabled }}
    namespace: {{ $gitops.Namespace }}
  quay:
    enabled: {{ $quay.Enabled }}
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

developerHub:
  namespace: {{ $rhdh.Namespace }}
  ingressDomain: {{ $ingressDomain }}
  catalogURL: {{ $catalogURL }}
  integrationSecrets:
    namespace: {{ .Installer.Namespace }}
  RBAC:
    adminUsers:
{{ dig "Properties" "RBAC" "adminUsers" (list "${GITHUB__USERNAME}") $rhdh | toYaml | indent 6 }}
    enabled: {{ dig "Properties" "RBAC" "enabled" false $rhdh }}
    orgs:
{{ dig "Properties" "RBAC" "orgs" (list "${GITHUB__ORG}") $rhdh | toYaml | indent 6 }}

#
# tssc-tpa-realm
#

{{- $tpaAppDomain := printf "-%s.%s" $tpa.Namespace $ingressDomain }}
{{- $tpaOIDCClientsSecretName := "tpa-realm-chicken-clients" }}
{{- $tpaTestingUsersEnabled := false }}
{{- $protocol := "https" -}}
{{- if $crc.Enabled }}
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
    walker:
      enabled: true
    testingManager:
      enabled: {{ $tpaTestingUsersEnabled }}
    testingUser:
      enabled: {{ $tpaTestingUsersEnabled }}
  frontendRedirectUris:
    - "http://localhost:8080"
{{- range list "console" "sbom" "vex" }}
    - "{{ printf "%s://%s-%s.%s" $protocol . $tpa.Namespace $ingressDomain }}"
    - "{{ printf "%s://%s-%s.%s/*" $protocol . $tpa.Namespace $ingressDomain }}"
{{- end }}
  integrationSecret:
    bombasticAPI: {{
      printf "%s://sbom-%s.%s"
        $protocol
        $tpa.Namespace
        $ingressDomain
    }}
    namespace: {{ .Installer.Namespace }}
    name: tssc-trustification-integration

#
# tssc-tpa
#

{{- $tpaGUACDatabaseSecretName := "guac-pguser-guac" }}

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
    useServiceCa: {{ not $crc.Enabled }}
  guac: &tpaGUAC
    database: &guacDatabase
      name:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName }}
      host:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName }}
      port:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName}}
      username:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName }}
      password:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaGUACDatabaseSecretName }}
    initDatabase: *guacDatabase
  storage: &tpaStorage
    endpoint: {{ printf "http://minio.%s.svc.cluster.local:80" $tpa.Namespace }}
    accessKey:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaMinIORootSecretName }}
    secretKey:
      valueFrom:
        secretKeyRef:
          name: {{ $tpaMinIORootSecretName }}
  eventBus:
    bootstrapServers: {{ $tpaKafkaBootstrapServers }}
    config:
      username: {{ $tpaKafkaSecretName }}
      password:
        valueFrom:
          secretKeyRef:
            name: {{ $tpaKafkaSecretName }}
  oidc: &tpaOIDC
    issuerUrl: {{ $tpaOIDCIssuerURL }}
    clients:
      walker:
        clientSecret:
          valueFrom:
            secretKeyRef:
              name: {{ $tpaOIDCClientsSecretName }}
              key: walker
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
  guac: *tpaGUAC
  ingress: *tpaIngress
  tls:
    serviceEnabled: "{{ not $crc.Enabled }}"

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
{{- if $crc.Enabled }}
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
