{{- define "common.preInstall" -}}
apiVersion: v1
kind: Pod
metadata:
  annotations:
    helm.sh/hook: pre-install,pre-upgrade
    helm.sh/hook-weight: "-1"
    helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded
  labels:
    {{- include "common.labels" . | nindent 4 }}
  name: pre-install-{{ .name | default .Chart.Name }}
  namespace: {{ .namespace | default .Release.Namespace }}
spec:
  restartPolicy: Never
  # Using the "default" SA for simplicity, the SA for the specific Helm chart will
  # only be created after the pre-install hook.``
  serviceAccountName: "default"
  initContainers:
    #
    # Copying the scripts that will be used on the subsequent containers, the
    # scripts are shared via the "/scripts" volume.
    #
{{- include "common.copyScripts" . | nindent 4 }}
  volumes:
    - name: scripts
      emptyDir: {}
{{- end -}}
