# `rhtap-minio-operator`: Development Guide

## Updating the MinIO Operator Helm Chart

This guide explains how to update the MinIO Operator Helm chart, which is used as a dependency in this project. The MinIO Operator Helm chart is available from the [upstream repository][minIOHelmRepo]. Follow the steps below to update the chart:

1. **Add the Upstream Repository**

   Add the MinIO Operator repository using the following commands:

   ```bash
   helm repo add minio-operator https://operator.min.io
   helm repo update
   ```

2. **List Available Versions**

   After adding the repository, list the available versions of the MinIO Operator chart:

   ```bash
   helm search repo minio-operator/operator --versions 
   ```

3. **Update Local Dependencies**

   Choose the desired version and update the local dependencies by running the following command, replacing `<VERSION>` with the desired version:

   ```bash
   helm pull minio-operator/operator \
       --version="<VERSION>" \
       --destination="installer/charts/rhtap-minio-operator/charts"
   ```

4. **Update References**

   Finally, update the references in the `Chart.yaml` file to reflect the new version.

[minIOHelmChart]: https://github.com/minio/operator/tree/master/helm
[minIOHelmRepo]: https://operator.min.io
