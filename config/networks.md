# Docker Network Architecture

## Network Isolation Strategy
- **infrastructure_traefik**: Web services and reverse proxy
- **infrastructure_database**: Backend data services (PostgreSQL, Redis)
- **applications**: User-facing services (Jellyfin, Immich, etc.)
- **monitoring**: Metrics and dashboards (Prometheus, Grafana)

## Service Placement Guidelines
- Web services that need external access: infrastructure_traefik + applications
- Databases and caches: infrastructure_database only
- Monitoring tools: monitoring + infrastructure_traefik (for web access)
