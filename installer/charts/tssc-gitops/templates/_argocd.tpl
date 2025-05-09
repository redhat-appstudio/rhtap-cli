{{/*

  Returns the fully qualified domain name for the ArgoCD server.

*/}}
{{- define "argoCD.serverHostname" -}}
  {{- $argoCD := .Values.argoCD -}}
  {{ printf "%s-server-%s.%s" $argoCD.name $argoCD.namespace $argoCD.ingressDomain }}
{{- end -}}

{{/*

  Returns the name of the secret that contains the ArgoCD admin password.

*/}}
{{- define "argoCD.secretClusterName" -}}
  {{ printf "%s-cluster" .Values.argoCD.name }}
{{- end -}}

{{/* 

  Creates a POD container spec for the ArgoCD login test.

*/}}
{{- define "argoCD.testArgoCDLogin" -}}
  {{- $argoCD := .Values.argoCD -}}
- name: {{ printf "argocd-login-%s" $argoCD.name }}
  image: registry.redhat.io/openshift-gitops-1/argocd-rhel8@sha256:5bfc4686983f9c62107772d99d900efbcc38175afe621c40958035aa49bfa9ed
  env:
    - name: ARGOCD_HOSTNAME
      value: {{ include "argoCD.serverHostname" . }}
    - name: ARGOCD_USER
      value: admin
    - name: ARGOCD_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "argoCD.secretClusterName" . }} 
          key: admin.password
  workingDir: /home/argocd
  command:
    - /scripts/argocd-helper.sh
  args:
    - login
  volumeMounts:
    - name: scripts
      mountPath: /scripts
  securityContext:
    runAsNonRoot: false
    allowPrivilegeEscalation: false
{{- end -}}
