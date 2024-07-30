# Configuration

Valkey configured through the upstream [Bitnami Valkey chart](https://github.com/bitnami/charts/tree/main/bitnami/valkey) as well as a UDS configuration chart that supports the following:

## Networking

Network policies are controlled via the `uds-valkey-config` chart in accordance with the [common patterns for networking within UDS Software Factory](https://github.com/defenseunicorns/uds-software-factory/blob/main/docs/networking.md).  Because Valkey does not interact with external resources like databases or object storage it only implements `custom` networking for the `valkey` namespace:

- `custom`: sets custom network policies for the `valkey` namespace (i.e. to allow clients like GitLab to connect)

## Cross-Namespace Password

Valkey is currently configured to expect a single user or workload to be using it - to enable this workload to exist in another namespace without needing elevated permissions itself, the `uds-valkey-config` chart supports the following keys to place the Valkey password in another namespace:

- `copyPassword.enabled`: enables the copying of the Valkey password secret to another namespace
- `copyPassword.namespace`: the namespace to copy the Kubernetes secret into
- `copyPassword.secretName`: the name to give the Kubernetes secret in the other namespace
- `copyPassword.secretKey`: the key to place the password under within the Kubernetes secret
