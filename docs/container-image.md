`tssc`: Container Image
----------------------------

# Abstract

The `tssc` container image is a portable and easy-to-use tool to deploy TSSC (Trusted Software Supply Chain) from a container manager running on your local machine. The container image is designed to enable the deployment process on Kubernetes Jobs, ArgoCD (GitOps), and other container orchestration tools.


# Usage

The installer needs access to the target OpenShift/Kubernetes instance, therefore you either need to mount the local `~/.kube/config` file or provide the necessary environment variables to authenticate with the target cluster.

## Podman

For the `tssc integration github-app` you need to expose the callback port, used on the GitHub App registration, to the container. The GitHub App registration requires a personal access token, which should be created for the specific organization TSSC will work on. In the example below, the token is passed as an environment variable `TSSC_GITHUB_TOKEN`.

The OpenShift configuration and credentials are passed to the container by mounting the local `~/.kube` directory to the container's `/root/.kube` directory. And the user `root` is employed to avoid permission issues, although the mounted directory is read-only.

A interactive shell is started in the container, where you can run the `tssc` commands.

```bash
podman run \
    --name="tssc" \
    --rm \
    --interactive \
    --tty \
    --env="TSSC_GITHUB_TOKEN=${TSSC_GITHUB_TOKEN}" \
    --publish="127.0.0.1:8228:8228" \
    --entrypoint="/bin/bash" \
    --user="root" \
    --volume="${HOME}/.kube:/root/.kube:ro" \
    ghcr.io/redhat-appstudio/rhtap-cli:latest
```

Before the installation you should review the [`config.yaml`](../README.md#configuration) file to decide what's appropriate for your environment, in this example we are using the default configuration.

In the container, you can run the `tssc` commands, for example, creating a GitHub App integration on the organization `tssc-example`, and using the same name for the GitHub App:

```bash
tssc integration github-app \
    --config="config.yaml" \
    --create \
    --token="${TSSC_GITHUB_TOKEN}" \
    --org="tssc-example" \
    --webserver-addr="0.0.0.0" \
    tssc-example
```

After configuring the integrations, you can proceed with the deployment:

```bash
tssc deploy
```
