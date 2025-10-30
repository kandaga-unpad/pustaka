# k3s / Kubernetes manifests for Voile

This folder contains ready-to-use manifests for deploying Voile to k3s. They are intended as a simple, working starting point for a small k3s cluster. For production usage consider replacing the Postgres deployment with a managed DB or a Helm chart (Bitnami/Postgres) configured for backups and replication.

Files
- `namespace.yaml` - creates the `voile` namespace.
- `secrets.yaml` - contains `stringData` placeholders for `SECRET_KEY_BASE`, `DATABASE_URL`, and Postgres credentials. Replace values or create a secret with `kubectl create secret`.
- `postgres-deployment.yaml` - a single-replica Postgres `Deployment` and a `PersistentVolumeClaim` using `local-path` storage class (k3s default).
- `voile-deployment.yaml` - the Voile `Deployment` (change image to your registry/tag).
- `voile-service.yaml` - ClusterIP service mapping port 80 to container 4000.
- `voile-ingress.yaml` - Ingress resource that uses `traefik` as the ingress controller. Change the host to your domain.

Apply in this order:

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/postgres-deployment.yaml
kubectl apply -f k8s/voile-deployment.yaml
kubectl apply -f k8s/voile-service.yaml
kubectl apply -f k8s/voile-ingress.yaml
```

Notes
- Replace `registry.example.com/voile:1.0` in `voile-deployment.yaml` with your pushed image reference.
- The manifests use `local-path` storage class (k3s default). If you use another storage class, edit `postgres-deployment.yaml` PVC accordingly.
- For production, prefer using a Helm chart for Postgres (bitnami/postgresql) or a managed DB.

Additional production notes
- Security: the Deployment now sets a pod-level `securityContext` to run as a non-root user (UID 1000) and `fsGroup` 1000 so mounted volumes are accessible.
- Resources: the app Deployment includes resource `requests` and `limits`. Tune these for your workload.
- Migrations: a `k8s/migrate-job.yaml` template is provided. Edit the `command` to match your release migration function (the example assumes `Voile.Release.migrate`). Run this job after pushing a new image to apply DB migrations before updating the Deployment.
- PodDisruptionBudget: `k8s/pdb.yaml` is included to maintain availability during node maintenance.

Applying the migration job example (edit before running):

```bash
# edit k8s/migrate-job.yaml to ensure the command matches your release migration function
kubectl apply -f k8s/migrate-job.yaml
kubectl wait --for=condition=complete job/voile-migrate -n voile --timeout=300s
kubectl delete job voile-migrate -n voile
```

