import json
import yaml
import argparse

# Parse command-line arguments
parser = argparse.ArgumentParser(description='Process Keycloak realm export.')
parser.add_argument('input', help='The input JSON file.')
parser.add_argument('output', help='The output YAML file.')
args = parser.parse_args()

# Load the JSON payload
with open(args.input, 'r') as json_file:
    data = json.load(json_file)

# Dictionary that matches the structure of the KeycloakRealmImport CRD
cr = {
    "apiVersion": "k8s.keycloak.org/v2alpha1",
    "kind": "KeycloakRealmImport",
    "metadata": {
        "labels": {
            "app": "keycloak"
        },
        "name": data['realm'],
    },
    "spec": {
        "keycloakCRName": "__OVERWRITE_ME__",
        "realm": data
    }
}

# Write the CR to a YAML file
with open(args.output, 'w') as yaml_file:
    yaml.dump(cr, yaml_file)
