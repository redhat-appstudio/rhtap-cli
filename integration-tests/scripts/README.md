## Deploying TSSC for development

Once you have a cluster ready:

1. Set up your `.env` file (or `.envrc` or whatever you prefer). Copy the `.env.template` file and fill in the values according to the inline instructions.
2. Source your `.env` file
3. Run `integration-tests/scripts/install.sh`
4. When finished, the script will print a Homepage URL, Webhook URL and Callback URL. Go to the GitHub or GitLab app that you used for TSSC integration and set these urls in the settings.

Note: 
1. once you've set up your .env for the first time, most of the variables will be re-usable for future deployments.

2. If you are going to use the hosted ACS that we already installed on rhtap-services Cluster, it's already configured the integration with our Artifactory, Nexus servers. 