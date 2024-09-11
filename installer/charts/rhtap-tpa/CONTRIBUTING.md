`rhtap-tap`: RHTAP Trusted Profile Analyzer
-------------------------------------------

# Contributing

## Keycloak Chicken Realm

Trustification components rely, by default, on Keycloak for SSO and authorizations.
Therefore the project will create a Realm named `chicken` for this purpose, relying on the Keycloak operator to manage the Realm installation.

To update the `KeycloakRealmImport` template follow the steps:

1. Run the project official installer against a Keycloak instance.
2. Use the instance UI to export the Realm, including `clients` and `roles` to a JSON file.
3. Use the Python script documented below to generate the `KeycloakRealmImport` CRD file.
4. Edit the project's Realm template with the generate file, be careful to merge secret attributes, redirect URIs and the `admin` user with the generated payload.

### Generate `KeycloakRealmImport` Script

Once you have the Realm export JSON file, use it as the first argument for the Python script:

```sh
python hack/generate-keycloakrealmimport.py <realm-export-json> <crd-yaml>
```

The second argument is the path of the output CRD YAML file.
