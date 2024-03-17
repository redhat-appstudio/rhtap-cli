{{- define "infrastructure.minIOTentants.namespaces.enabled" -}}
  {{- $namespaces := list }}
  {{- range $v := .Values.infrastructure.minIOTentants -}}
    {{- if and $v.enabled (not (has $v.namespace $namespaces)) -}}
      {{- $namespaces = append $namespaces $v.namespace -}}
    {{- end -}}
  {{- end -}}
  {{- $namespaces | toJson -}}
{{- end -}}

{{- define "infrastructure.minIOTentants.enabled" -}}
  {{- $enabled := dict -}}
  {{- range $k, $v := .Values.infrastructure.minIOTentants -}}
    {{- if $v.enabled -}}
      {{- $enabled = merge $enabled (dict $k $v) -}}
    {{- end -}}
  {{- end -}}
  {{- $enabled | toYaml -}}
{{- end -}}
