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

## High Availability

The default Valkey configuration is a single read/write node, which is sufficient for most use cases. For example, GitLab recommends a single-node architecture even in [their 2,000 user reference architecture](https://docs.gitlab.com/ee/administration/reference_architectures/2k_users.html). They only suggest replication starting with [their 3000 user reference architecture](https://docs.gitlab.com/ee/administration/reference_architectures/3k_users.html) (note that the pages linked refer to Redis, for which Valkey is a drop-in replacement). For scenarios requiring higher availability, this package also supports a replicated architecture.

### Configuration Changes

The configuration changes required to switch from the standalone to the replicated (with sentinel) architecture can be derived by comparing the two valkey instances in the [test bundle definition](../bundle/uds-bundle.yaml). The changes are as follows:

1. Add an ingress to the sentinel port in the `custom` network rules in the `uds-valkey-config` chart. This is unnecessary if not enabling the sentinel later (not recommended).

```yaml
packages:
  - name: valkey
    overrides:
      valkey:
        uds-valkey-config:
          values:
            - direction: Ingress
                selector:
                app.kubernetes.io/name: valkey
                remoteNamespace: <your application's namespace>
                remoteSelector:
                app: <your application's UDS Package app name>
                port: 26379
                description: "Ingress from <your application> to sentinel"
```

2. Set the desired number of `replicas` in the `uds-valkey-config` chart. Note this defaults to zero for the standalone instance in order to prevent the creation of network policies which are only needed to support Valkey's clustering behavior.

```yaml
packages:
  - name: valkey
    overrides:
      valkey:
        uds-valkey-config:
          values:
            - path: replicas
              value: 3
```

3. Set the [`architecture` variable in the upstream valkey chart](https://github.com/bitnami/charts/blob/main/bitnami/valkey/values.yaml#L128) to `replication` and turn on the sentinel (recommended).

```yaml
packages:
  - name: valkey
    overrides:
      valkey:
        valkey:
          values:
            - path: architecture
              value: replication
            - path: sentinel.enabled
              value: true
```

### Impacts

This high-availability configuration will result in a few changes, some obvious, some less obvious:

1. The single `valkey-master` pod will be replaced by pods named `valkey-node-0`, `valkey-node-1`, and so on per the requested number of `replicas`.
2. Every `valkey-node` pod will now includes a Sentinel sidecar. It is accessed by contacting the valkey service at the Sentinel port `26379` rather than the read/write port `6379`.
3. As may be guessed from those two changes, the valkey service name also changes from `valkey-master.<valkey namespace>.svc.cluster.local` to, depending on your use-case:

    - `valkey.<valkey namespace>.svc.cluster.local:26379` if trying to access a Sentinel.
    - `valkey.<valkey namespace>.svc.cluster.local:6379` if trying to _read_ data.
    - `valkey-node-<?>.valkey-headless.<valkey namespace>.svc.cluster.local:6379` if trying to _write_ data.

      > Note the `<?>` in that address. The write node (called the Primary node) is only known by asking a Sentinel for the address and can change dynamically. Calling the sentinel to know where the primary node is should be handled by the calling application and so not relevant to most bundle development. If a Redis-ready application is given the address of the Sentinel service and the _read_ service that should be enough. For further clarity, see the Redis or Valkey documentation and review the tests for this application package where the Valkey CLI is used to communicate with both the standalone and replicated instances defined in the test bundle.

### Alternative: Replication without Sentinel

If the `sentinel.enabled` value above is set to `false` then one node will be the primary, the others read-replicas, and valkey will be unable to recover from the loss of that primary node. This is not recommended. The write node address will also need to be given at deploy-time to client applications. This configuration should be entirely possible with minimal if any changes to the UDS Package but is an exercise left to the reader.
