{{- define "infrastructure.minIOTentant.secretName" -}}
{{ . }}-root-env
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
