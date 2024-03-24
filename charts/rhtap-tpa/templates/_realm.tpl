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
