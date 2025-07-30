## Deploying RHADS for development

Once you have a cluster ready:

1. Set up your `.env` file (or `.envrc` or whatever you prefer). Copy the `.env.template` file and fill in the values according to the inline instructions.
2. Source your `.env` file
3. Run `integration-tests/scripts/install.sh`
4. When finished, the script will print a Homepage URL. You can then manually configure webhook URLs and callback URLs in your GitHub or GitLab app settings using the Homepage URL as the base.

## Using install.sh for RHADS Deployment

The `install.sh` script supports flexible deployment configurations through environment variables. You can customize your RHADS deployment by setting these configuration arrays in your `.env` file:

### Configuration Options

#### ACS/TPA Configuration
```bash
# Example: Deploy local ACS instance (default)
export acs_config="local"

# Example: Use remote/existing TPA instance
export tpa_config="remote"
```

**Options**: `local` OR `remote` (single value only)
- `local`: Installs ACS/TPA locally in your cluster
- `remote`: Connects to an existing external ACS/TPA instance


#### Registry Configuration
```bash
# Example: Use multiple registries (comma-separated)
export registry_config="quay,artifactory,nexus"
```

**Options**: `quay`, `artifactory`, `nexus` (can be multiple values)
- `quay`: Integrates with external Quay.io service
- `artifactory`: Integrates with Artifactory registry
- `nexus`: Integrates with Nexus registry
- Multiple values: Comma-separated list to integrate with multiple registries

#### SCM (Source Code Management) Configuration
```bash
# Example: Use multiple SCMs (comma-separated)
export scm_config="github,gitlab"
```

**Options**: `github`, `gitlab`, `bitbucket` (can be multiple values)
- `github`: Integrates with GitHub
- `gitlab`: Integrates with GitLab
- `bitbucket`: Integrates with Bitbucket
- Multiple values: Comma-separated list to integrate with multiple SCM providers

#### Pipeline Configuration
```bash
# Example: Use multiple pipelines (comma-separated)
export pipeline_config="tekton,jenkins"
```

**Options**: `tekton`, `jenkins` (can be multiple values)
- `tekton`: Uses Tekton pipelines (OpenShift Pipelines)
- `jenkins`: Integrates with external Jenkins server
- `azure`: Integrates with Azure DevOps pipelines
- `actions`: Uses GitHub Actions pipelines (requires `github` in SCM config)
- `gitlabci`: Uses GitLab CI pipelines (requires `gitlab` in SCM config)
- Multiple values: Comma-separated list to use the pipeline systems


Note: 
1. once you've set up your .env for the first time, most of the variables will be re-usable for future deployments.

2. If you are going to use the hosted ACS that we already installed on rhtap-services Cluster, it's already configured the integration with our Artifactory, Nexus servers. 