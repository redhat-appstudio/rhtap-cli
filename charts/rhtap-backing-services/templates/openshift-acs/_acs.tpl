{{/*

  Returns the ACS URL for the given environment.

*/}}
{{- define "backingServices.acs.centralURL" -}}
  {{- $acs := .Values.backingServices.acs -}}
  {{- printf "https://central-%s.%s" $acs.namespace $acs.ingressDomain -}}
{{- end -}}
