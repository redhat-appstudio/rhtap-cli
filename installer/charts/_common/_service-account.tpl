{{- define "common.serviceAccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  labels: {{- include "common.postDeployDeleteLabels" . | nindent 4 }}
{{- end }}
{{- define "common.clusterRoleBinding" -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ .Release.Name }}
  labels: {{- include "common.postDeployDeleteLabels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ .Release.Name }}
subjects:
  - kind: ServiceAccount
    name: {{ .Release.Name }}
    namespace: {{ .Release.Namespace }}
{{- end }}
{{- define "common.clusterRoleBindingClusterAdmin" -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: {{ .Release.Name }}
  labels: {{- include "common.postDeployDeleteLabels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: {{ .Release.Name }}
    namespace: {{ .Release.Namespace }}
{{- end }}
