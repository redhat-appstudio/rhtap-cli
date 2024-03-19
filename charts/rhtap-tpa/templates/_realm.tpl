{{- define "keycloakRealmImport.spec.clients.attributes" -}}
clientAuthenticatorType: client-secret
publicClient: false
implicitFlowEnabled: false 
standardFlowEnabled: false
directAccessGrantsEnabled: false
serviceAccountsEnabled: true
fullScopeAllowed: true
webOrigins:
  - "*"
attributes:
  access.token.lifespan: "300"
  post.logout.redirect.uris: "+"
protocol: openid-connect
{{- end -}}

{{- define "keycloakRealmImport.spec.clients.defaultClientScopes" -}}
- email
- profile
- roles
- web-origins
- read:document
{{- end -}}

{{- define "keycloakRealmImport.spec.clients.optionalClientScopes" -}}
- address
- microprofile-jwt
- offline_access
- phone
{{- end -}}

{{- define "keycloakRealmImport.clients.enabled" -}}
  {{- $enabled := dict -}}
  {{- range $k, $v := .Values.trustedProfileAnalyzer.keycloakRealmImport.clients -}}
    {{- if $v.enabled -}}
      {{- $enabled = merge $enabled (dict $k $v) -}}
    {{- end -}}
  {{- end -}}
  {{- $enabled | toYaml -}}
{{- end -}}

{{- define "generate.client.secret" -}}
{{-
  printf "%s-%s-%s-%s-%s"
    (randAlphaNum 8)
    (randAlphaNum 4)
    (randAlphaNum 4)
    (randAlphaNum 4)
    (randAlphaNum 12)
-}}
{{- end -}}
