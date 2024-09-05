{{- define "infrastructure.kafkas.enabled" -}}
  {{- $enabled := dict -}}
  {{- range $k, $v := .Values.infrastructure.kafkas -}}
    {{- if $v.enabled -}}
      {{- $enabled = merge $enabled (dict $k $v) -}}
    {{- end -}}
  {{- end -}}
  {{- $enabled | toYaml -}}
{{- end -}}
