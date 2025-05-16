# E2E integration tests

This folder contains resources for running multi-level e2e for TSSC in Konflux

## Prerequisites
In order to succesfully run this integration test one must:
* Create [Role](./custom-resources/plrManager-Role.yaml) that is capable of starting & watching PipelineRuns 
* Create a [RoleBinding](./custom-resources/plrManager-RoleBinding.yaml) binding that role to `appstudio-pipeline` SA (default SA used by Tekton in Konflux)
* Create [IntegrationTestScenario](./custom-resources/e2e-IntegrationTestScenario.yaml) in Konflux tenant.
* Create necessary secrets in the Konflux tenant
    * `sprayproxy-auth` used to register ephemeray cluster with sprayproxy with keys:
        * `server-token`
        * `server-url`
    * `rhtap-cli-install` used by `rhtap-install` task with keys:
        * `quay-dockerconfig-json: `
        * `docker_io: `
        * `rhdh-github-client-id`
        * `acs-central-endpoint`
        * `acs-api-token`
        * `bitbucket-username`
        * `jenkins-username`
        * `jenkins-api-token`
        * `gitlab_token`
        * `quay-api-token`
        * `jenkins-url`
        * `rhdh-github-client-secret`
        * `bitbucket-app-password`
        * `rhdh-github-webhook-secret`
        * `github_token`
        * `rhdh-github-app-id`
        * `rhdh-github-private-key`
    * `konflux-test-infra` with keys:
        * `qe-cloud-credentials-us-east-1` - this is current default key holding AWS credentials json. Other key might be used based on what's defined in `cloud-credential-key` parameter of `rhtap-cli-e2e` Pipeline.
        * `github-bot-commenter-token`
        * `oci-storage`

## Pipelines used

### e2e-main-pipeline

This is the main pipeline used by our IntegrationTestScenario. It has 3 phases
1) Downloads & parses [Pict](https://github.com/Microsoft/pict/blob/main/doc/pict.md) file from fork's location `./integration-tests/pict-models/default.pict`. This defines the matrix for this e2e run
2) Creates new PipelineRun for each row of the matrix defined by used Pict model file using [rhtap-cli-e2e Pipeline](./pipelines/rhtap-cli-e2e.yaml)
3) Waits for all "nested" pipelines to finish.

### rhtap-cli-e2e

Pipeline that given parameters:
1) Creates ephemeral cluster
2) Installs TSSC
3) Runs rhtap-e2e tests
4) Teardown (archive artifacts, destroy cluster, ...)
