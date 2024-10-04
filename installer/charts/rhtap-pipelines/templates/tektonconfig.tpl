{{- define "pipelines.tektonconfig" -}}
---
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  labels:
    {{- include "rhtap-pipelines.labels" . | nindent 4 }}
  name: config
spec:
  addon:
    params:
      - name: clusterTasks
        value: 'true'
      - name: communityClusterTasks
        value: 'true'
      - name: pipelineTemplates
        value: 'true'
  chain:
    artifacts.oci.storage: oci
    artifacts.pipelinerun.format: in-toto
    artifacts.pipelinerun.storage: oci
    artifacts.taskrun.format: in-toto
    artifacts.taskrun.storage: oci
    disabled: false
    transparency.enabled: 'true'
    transparency.url: http://rekor-server.rhtap-tas.svc
  config: {}
  dashboard:
    options:
      disabled: false
    readonly: false
  hub:
    options:
      disabled: false
  params:
    - name: createRbacResource
      value: 'true'
  pipeline:
    await-sidecar-readiness: true
    coschedule: workspaces
    default-service-account: pipeline
    disable-affinity-assistant: true
    disable-creds-init: false
    enable-api-fields: beta
    enable-bundles-resolver: true
    enable-cel-in-whenexpression: false
    enable-cluster-resolver: true
    enable-custom-tasks: true
    enable-git-resolver: true
    enable-hub-resolver: true
    enable-param-enum: false
    enable-provenance-in-status: true
    enable-step-actions: false
    enable-tekton-oci-bundles: true
    enforce-nonfalsifiability: none
    keep-pod-on-cancel: false
    max-result-size: 4096
    metrics.count.enable-reason: false
    metrics.pipelinerun.duration-type: histogram
    metrics.pipelinerun.level: pipeline
    metrics.taskrun.duration-type: histogram
    metrics.taskrun.level: task
    options:
      disabled: false
    params:
      - name: enableMetrics
        value: 'true'
    performance:
      disable-ha: false
    require-git-ssh-secret-known-hosts: false
    results-from: termination-message
    running-in-environment-with-injected-sidecars: true
    send-cloudevents-for-runs: false
    set-security-context: false
    trusted-resources-verification-no-match-policy: ignore
  platforms:
    openshift:
      pipelinesAsCode:
        enable: true
        options:
          disabled: false
        settings:
          application-name: RHTAP CI
          auto-configure-new-github-repo: 'false'
          bitbucket-cloud-check-source-ip: 'true'
          custom-console-name: ''
          custom-console-url: ''
          custom-console-url-pr-details: ''
          custom-console-url-pr-tasklog: ''
          error-detection-from-container-logs: 'true'
          error-detection-max-number-of-lines: '50'
          error-detection-simple-regexp: '^(?P<filename>[^:]*):(?P<line>[0-9]+):(?P<column>[0-9]+):([ ]*)?(?P<error>.*)'
          error-log-snippet: 'true'
          remember-ok-to-test: 'false'
          remote-tasks: 'true'
          secret-auto-create: 'true'
          secret-github-app-token-scoped: 'true'
      scc:
        default: pipelines-scc
  profile: all
  pruner:
    disabled: false
    keep: 100
    resources:
      - pipelinerun
    schedule: 0 8 * * *
  targetNamespace: openshift-pipelines
  trigger:
    default-service-account: pipeline
    enable-api-fields: stable
    options:
      disabled: false
{{- end -}}
