{{- define "infrastructure.minIOTenants.namespaces.enabled" -}}
  {{- $namespaces := list }}
  {{- range $v := .Values.infrastructure.minIOTenants -}}
    {{- if and $v.enabled (not (has $v.namespace $namespaces)) -}}
      {{- $namespaces = append $namespaces $v.namespace -}}
    {{- end -}}
  {{- end -}}
  {{- $namespaces | toJson -}}
{{- end -}}

{{- define "infrastructure.minIOTenants.enabled" -}}
  {{- $enabled := dict -}}
  {{- range $k, $v := .Values.infrastructure.minIOTenants -}}
    {{- if $v.enabled -}}
      {{- $enabled = merge $enabled (dict $k $v) -}}
    {{- end -}}
  {{- end -}}
  {{- $enabled | toYaml -}}
{{- end -}}
