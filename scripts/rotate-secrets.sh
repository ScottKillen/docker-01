#!/bin/bash
set -euo pipefail

SECRETS_DIR="/opt/docker/secrets"
BACKUP_DIR="/opt/docker/backups/secrets/$(date +%Y%m%d_%H%M%S)"

echo "=== Docker Secrets Rotation ==="
echo "Backup directory: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup existing secrets
echo "Backing up current secrets..."
cp -r "$SECRETS_DIR"/* "$BACKUP_DIR"/ 2>/dev/null || echo "No existing secrets to backup"

# Generate new secrets
echo "Generating new secrets..."
openssl rand -base64 32 > "$SECRETS_DIR/postgres_password.txt"
openssl rand -base64 32 > "$SECRETS_DIR/redis_password.txt"
openssl rand -base64 32 > "$SECRETS_DIR/grafana_admin_password.txt"

# Update permissions
chmod 600 "$SECRETS_DIR"/*.txt

echo "Secrets rotated successfully!"
echo "Backup stored in: $BACKUP_DIR"
echo ""
echo "IMPORTANT: Restart services to apply new secrets:"
echo "  cd /opt/docker/compose/infrastructure"
echo "  docker compose restart postgres redis"
echo ""
echo "Update Redis password in docker-compose.yml manually after rotation."
