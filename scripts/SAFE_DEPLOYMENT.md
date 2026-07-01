# Safe Deployment Guide

## What Changed

### 1. Safe Update Scripts

Both `update_simple.sh` and `update_full.sh` now have **automatic rollback** on any failure:

| Failure Type | Behavior |
|--------------|----------|
| Build fails | System unchanged, old version still running |
| Migrations fail | System unchanged, old version still running |
| Container crashes | Automatic rollback to previous version |
| Health check fails | Automatic rollback to previous version |

### 2. Image Backup Strategy

- Before update: `voile:latest` → tagged as `voile:backup`
- During update: New image built as `voile:new-[timestamp]` (NOT `voile:latest`)
- After successful update:
  - `voile:new-[timestamp]` → tagged as `voile:latest`
  - `voile:backup` → archived as `voile:backup-[timestamp]`

### 3. Zero Downtime Migrations

Old container continues running while migrations are tested on new image:
```
┌────────────────────────────────────────────┐
│ OLD VERSION (still serving traffic)        │
├────────────────────────────────────────────┤
│ ✓ Running                                   │
│ ✓ Serving requests                          │
└────────────────────────────────────────────┘

Running migrations on NEW image...

If migrations FAIL → old version continues (no downtime)
If migrations PASS → stop old, start new, health check
If health check FAIL → rollback to old version
```

---

## How to Deploy

### Simple Update (recommended for most cases)

```bash
# On server
./scripts/update_simple.sh
```

### Full Update (includes DB backup)

```bash
# On server
./scripts/update_full.sh
```

---

## How to Rollback

### List available backups

```bash
./scripts/manage.sh rollback
```

Example output:
```
Available rollback images:

voile:backup-20241229-143025  abc123  2 hours ago  1.2GB
voile:backup-20241228-092215  def456  1 day ago     1.15GB

Current backup available: voile:backup
Usage: ./manage.sh rollback-to <image-name>
```

### Rollback to specific version

```bash
./scripts/manage.sh rollback-to voile:backup-20241229-143025
```

### Quick rollback to previous version

```bash
./scripts/manage.sh rollback-to voile:backup
```

---

## Testing SSL Config

To test `force_ssl` with runtime config (without recompiling):

1. **Remove from prod.exs:**
   ```elixir
   config :voile, VoileWeb.Endpoint,
     cache_static_manifest: "priv/static/cache_manifest.json"
     # force_ssl removed
   ```

2. **Add to runtime.exs (inside the Endpoint config block):**
   ```elixir
   config :voile, VoileWeb.Endpoint,
     # ... other config ...
     force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto]],
     secret_key_base: secret_key_base
   ```

3. **Commit, push, and deploy** with safe update:
   ```bash
   git add config/
   git commit -m "Test force_ssl at runtime"
   git push
   ./scripts/update_simple.sh  # or update_full.sh
   ```

4. **If it works** — great! Move `force_ssl` to `prod.exs` for production

5. **If it fails** — automatic rollback protects your production

---

## Important Notes

### Before First Deployment

Run `deploy.sh` first to set up the pod and containers:
```bash
./scripts/deploy.sh
```

### Commit Changes Before Update

The scripts use `git pull`, so **you must commit and push changes** before updating:
```bash
git add .
git commit -m "Your changes"
git push
```

### Cleanup Old Backups

Periodically clean up old backup images to save disk space:
```bash
# List backup images
podman images | grep voile.*backup

# Remove old backups (example)
podman rmi voile:backup-20241228-092215 voile:backup-20241227-120000
```

### When NOT to Use Safe Update

- First deployment (use `deploy.sh`)
- Major infrastructure changes (DB migration requiring downtime)
- Manual testing needed before production switch

---

## Troubleshooting

### Migration Failures

If migrations fail, the old version is still running. Check logs:
```bash
./scripts/manage.sh logs
```

### Container Won't Start

Check for config errors:
```bash
podman logs voile-app --tail 100
```

### Rollback Fails

Manually restore:
```bash
# List images
podman images | grep voile

# Tag and restart
podman tag voile:backup-YYYYMMDD-HHMMSS voile:latest
podman stop voile-app && podman rm voile-app
podman run -d --name voile-app --pod voile-pod ... voile:latest
```

---

## Script Reference

| Script | Purpose |
|--------|---------|
| `deploy.sh` | First-time deployment (creates pod, containers) |
| `update_simple.sh` | Safe update with rollback |
| `update_full.sh` | Safe update + DB backup |
| `manage.sh` | Management (logs, restart, rollback, etc.) |