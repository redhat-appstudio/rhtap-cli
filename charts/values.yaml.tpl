{{- $crc := required "CRC settings required" .Installer.Features.CRC -}}
{{- $tas := required "TAS settings required" .Installer.Features.TrustedArtifactSigner -}}
{{- $tpa := required "TPA settings required" .Installer.Features.TrustedProfileAnalyzer -}}
{{- $keycloak := required "Keycloak settings required" .Installer.Features.Keycloak -}}
{{- $rhdh := required "RHDH settings required" .Installer.Features.RedHatDeveloperHub -}}
{{/* TODO: bring information from the cluster, like ingress domain */}}
{{- $ingresDomain := "apps-crc.testing" -}}
---
#
# rhtap-openshift
#

openshift:
  projects:
{{- if $keycloak.Enabled }}
    - {{ $keycloak.Namespace }}
{{- end }}
{{- if $tas.Enabled }}
    - {{ $tas.Namespace }}
{{- end }}
{{- if $tpa.Enabled }}
    - rhbk-operator
    - minio-operator
    - {{ $tpa.Namespace }}
{{- end }}
{{- if $rhdh.Enabled }}
    - {{ $rhdh.Namespace }}
{{- end }}

#
# rhtap-subscriptions
#

subscriptions:
  amqStreams:
    enabled: {{ $tpa.Enabled }}
  crunchyData:
    enabled: {{ or $tpa.Enabled $rhdh.Enabled }}
  minIO:
    enabled: {{ $tpa.Enabled }}
  openshiftGitOps:
    enabled: {{ $rhdh.Enabled }}
    config:
      argoCDClusterNamespace: {{ default "empty" $rhdh.Namespace }}
  openshiftKeycloak:
    enabled: {{ $keycloak.Enabled }}
    operatorGroup:
      targetNamespaces:
        - {{ default "empty" $keycloak.Namespace }}
  openshiftPipelines:
    enabled: {{ $rhdh.Enabled }}
  openshiftTrustedArtifactSigner:
    enabled: {{ $tas.Enabled }}

#
# rhtap-infrastructure
#

{{- $tpaKafkaSecretName := "tpa-kafka" }}
{{- $tpaKafkaBootstrapServers := "tpa-kafka-bootstrap:9092" }}
{{- $tpaMinIORootSecretName := "tpa-minio-root-env" }}

infrastructure:
  kafkas:
    tpa:
      enabled: {{ $tpa.Enabled }}
      namespace: {{ $tpa.Namespace }}
      username: {{ $tpaKafkaSecretName }}
  minIOTentants:
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

#
# rhtap-backing-services
#

{{- $keycloakRouteTLSSecretName := "keycloak-tls" }}
{{- $keycloakRouteHost := printf "keycloak-%s.%s" $tpa.Namespace $ingresDomain }}

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
        enabled: false
        secretName: {{ $keycloakRouteTLSSecretName }}
        termination: reencrypt
{{- if $crc.Enabled }}
      annotations:
        route.openshift.io/termination: reencrypt
{{- end }}
    service:
      annotations:
        service.beta.openshift.io/serving-cert-secret-name: {{ $keycloakRouteTLSSecretName }}

#
# rhtap-tpa
#

{{- $tpaAppDomain := printf "-%s.%s" $tpa.Namespace $ingresDomain }}
{{- $guacDatabaseSSLMode := "disable" }}
{{- $guacDatabaseSecretName := "guac-pguser-guac" }}

trustedProfileAnalyzer:
  enabled: {{ $tpa.Enabled }}
  appDomain: {{ $tpaAppDomain}}
  keycloakRealmImport:
    enabled: {{ $keycloak.Enabled }}
    keycloakCR:
      namespace: {{ $keycloak.Namespace }}
      name: keycloak

trustification:
  appDomain: {{ $tpaAppDomain }}
  guac:
    database: &guacDatabase
      sslMode: {{ $guacDatabaseSSLMode }}
      name:
        valueFrom:
          secretKeyRef:
            name: {{ $guacDatabaseSecretName }}
      host:
        valueFrom:
          secretKeyRef:
            name: {{ $guacDatabaseSecretName }}
      port:
        valueFrom:
          secretKeyRef:
            name: {{ $guacDatabaseSecretName}}
      username:
        valueFrom:
          secretKeyRef:
            name: {{ $guacDatabaseSecretName }}
      password:
        valueFrom:
          secretKeyRef:
            name: {{ $guacDatabaseSecretName }}
    initDatabase: *guacDatabase
  storage:
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
  oidc:
    # TODO: enable/disable HTTPS depending on CRC status.
    issuerUrl: {{ printf "http://%s/realms/chicken" $keycloakRouteHost }}
