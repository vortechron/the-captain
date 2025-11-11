 1. Re-run k8s/infra/db/scripts/run-manual-backup.sh anytime; it will emit a valid dataset plus metadata.
  2. Restore the latest backup with SKIP_VERIFY=true SKIP_CONFIRM=true k8s/infra/db/scripts/run-manual-restore.sh manual-backup-20251110-224340 (or another backup
     name) and watch the CR restore-<timestamp>; it should report state: Succeeded like restore-20251110-224515.