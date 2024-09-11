{{/*

  Returns the ACS URL for the given environment.

*/}}
{{- define "backingServices.acs.centralEndPoint" -}}
  {{- $acs := .Values.backingServices.acs -}}
  {{- printf "central-%s.%s" $acs.namespace $acs.ingressDomain -}}
{{- end -}}
