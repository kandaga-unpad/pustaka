# CI & Production Deployment (GitHub Actions -> k3s)

This document describes the CI workflow added to `.github/workflows/ci.yml` and how to configure GitHub secrets and your production k3s server to allow automated build, push, and deploy.

What the workflow does

- On push to `main` (or manual dispatch):
  - Checks out the repo
  - Sets up Elixir/OTP and Node.js
  - Installs deps, builds assets, compiles and creates a Mix release
  - Builds a container image using the `Containerfile` and pushes it to your registry
  - Updates the `voile` Deployment image and reapplies the `k8s/` manifests

Required GitHub secrets

- `REGISTRY_URL` — the full registry hostname (e.g. `ghcr.io/your-org` or `registry.example.com`)
- `REGISTRY_USERNAME` — username to log in to the container registry
- `REGISTRY_PASSWORD` — password or token for the registry
- `KUBE_CONFIG_DATA` — base64-encoded kubeconfig content for the k3s cluster

How to produce `KUBE_CONFIG_DATA` safely

1. On a bastion or machine that has `kubectl` and access to the cluster, create a kubeconfig file scoped to a service account with minimal RBAC to update the namespace `voile`.

2. Create a service account in the cluster and bind a role (example manifests below):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gha-deployer
  namespace: voile
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gha-deployer-role
  namespace: voile
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints", "persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["create", "get", "list", "watch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gha-deployer-binding
  namespace: voile
subjects:
  - kind: ServiceAccount
    name: gha-deployer
    namespace: voile
roleRef:
  kind: Role
  name: gha-deployer-role
  apiGroup: rbac.authorization.k8s.io
```

3. Create a kubeconfig for that service account (example helper):

```bash
# set variables
NAMESPACE=voile
SA=gha-deployer
SECRET_NAME=$(kubectl -n $NAMESPACE get sa $SA -o jsonpath="{.secrets[0].name}")
TOKEN=$(kubectl -n $NAMESPACE get secret $SECRET_NAME -o jsonpath="{.data.token}" | base64 --decode)
CA_CERT=$(kubectl -n $NAMESPACE get secret $SECRET_NAME -o jsonpath="{.data['ca.crt']}")
API_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

cat > gha-kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA_CERT}
    server: ${API_SERVER}
  name: gha-cluster
contexts:
- context:
    cluster: gha-cluster
    namespace: ${NAMESPACE}
    user: gha-user
  name: gha-context
current-context: gha-context
users:
- name: gha-user
  user:
    token: ${TOKEN}
EOF

# base64 encode for secret
base64 -w0 gha-kubeconfig
```

4. Copy the base64 output and add it to the GitHub repo secrets as `KUBE_CONFIG_DATA`.

How to set other GitHub secrets

- For GitHub Container Registry (ghcr.io) you can use your PAT as `REGISTRY_PASSWORD` and your username as `REGISTRY_USERNAME`.
- For other registries, create a CI user with push permission and use its credentials.

How to trigger a deployment

- Push a commit to `main`.
- Or run the workflow manually from the GitHub Actions UI.

Rollbacks and image tags

- The workflow pushes both an immutable tag (the commit SHA) and `latest`. For production rollbacks prefer referencing the SHA tag in the Deployment so your rollbacks are precise.

Notes and security

- The kubeconfig and registry credentials are sensitive. Grant the CI service account minimal RBAC rights (namespace-scoped) and rotate credentials regularly.
- Consider configuring image scanning and signing in your pipeline for added security.

Troubleshooting

- If `kubectl` fails in the Actions job, check that `KUBE_CONFIG_DATA` is a valid base64-encoded kubeconfig and that the service account has the necessary RBAC.
- If image push fails, verify `REGISTRY_URL`, `REGISTRY_USERNAME`, and `REGISTRY_PASSWORD` secrets and that the registry accepts login from GitHub Actions runners.

If you'd like, I can:
- Add a separate ``deploy`` workflow that only runs deployment steps and is triggered by a release tag.
- Add Helm support to the workflow.
- Use buildah/podman in CI instead of docker actions (requires runner setup).

*** End of file
