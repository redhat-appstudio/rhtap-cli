{{- /*
  Select the enabled subscriptions.
*/ -}}
{{- define "subscriptions.enabled" -}}
  {{- $enabled := dict -}}
  {{- range $k, $v := .Values.subscriptions -}}
    {{- if $v.enabled -}}
      {{- $enabled = merge $enabled (dict $k $v) -}}
    {{- end -}}
  {{- end -}}
  {{- $enabled | toYaml -}}
{{- end -}}
