{{- define "backingServices.keycloak.name" -}}
{{- print "keycloak" -}}
{{- end -}}

{{- define "backingServices.keycloak.domainName" -}}
  {{- printf "%s-%s.%s"
      (include "backingServices.keycloak.name" .)
      .Values.backingServices.keycloak.namespace
      .Values.backingServices.keycloak.route.domain -}}
{{- end -}}
