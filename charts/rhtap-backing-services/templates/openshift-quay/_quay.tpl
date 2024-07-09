{{- define "backingServices.quay.configSecretName" -}}
  {{- printf "%s-config" .Values.backingServices.quay.name }}
{{- end -}}

{{/*

  Quay "quay_config.yaml" file template. Uses the configured S3 storage
  credentials secret to populate the S3 storage configuration.

*/}}
{{- define "backingServices.quay.s3storage.configYAML" -}}
  {{- $quay := .Values.backingServices.quay -}}
  {{- $cfg := $quay.config.radosGWStorage -}}
# Secret '{{ printf "%s/%s" $quay.namespace $cfg.credentials.secretName }}'
  {{- $secretObj := (lookup "v1" "Secret" $quay.namespace $cfg.credentials.secretName) | required ".quay.config.s3Storage.credentials.secretName must exist!" }}
  {{- $secretData := (get $secretObj "data") | default dict }}
# AccessKey: '{{ $cfg.credentials.accessKey }}'
  {{- $accessKey := (get $secretData $cfg.credentials.accessKey) | default "" }}
# SecretKey: '{{ $cfg.credentials.secretKey }}'
  {{- $secretKey := (get $secretData $cfg.credentials.secretKey) | default "" }}
DISTRIBUTED_STORAGE_CONFIG:
  default:
  - RadosGWStorage
  - access_key: "{{ $accessKey | b64dec }}"
    secret_key: "{{ $secretKey | b64dec }}"
    bucket_name: "{{ $cfg.bucketName }}"
    hostname: "{{ $cfg.hostname }}"
    port: "{{ $cfg.port | default 443 }}"
    is_secure: {{ $cfg.isSecure }}
    storage_path: {{ $cfg.storagePath | default "" | quote }}
{{- end -}}
