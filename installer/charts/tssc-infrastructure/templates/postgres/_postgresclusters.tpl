{{- /*
  Select the enabled infrastructure PostresClusters.
*/ -}}
{{- define "infrastructure.postgresClusters.enabled" -}}
  {{- $enabled := dict -}}
  {{- range $k, $v := .Values.infrastructure.postgresClusters -}}
    {{- if $v.enabled -}}
      {{- $enabled = merge $enabled (dict $k $v) -}}
    {{- end -}}
  {{- end -}}
  {{- $enabled | toYaml -}}
{{- end -}}
