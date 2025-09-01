#!/bin/bash

# Enhanced Manual Deploy Services Script
# Location: /opt/docker/scripts/deploy-services.sh
# Focus: Eliminate manual network steps while keeping full manual control

set -euo pipefail

# Configuration
DOCKER_COMPOSE_DIR="/opt/docker/compose"
SCRIPTS_DIR="/opt/docker/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Simple logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
}

log_info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Enhanced Deploy Services - Manual Control with Network Automation"
    echo ""
    echo "Usage: $0 [SERVICE] [OPTIONS]"
    echo ""
    echo "Services:"
    echo "  filebrowser    Deploy File Browser service"
    echo "  syncthing      Deploy Syncthing service"
    echo "  wikijs         Deploy Wiki.js service"
    echo "  memos          Deploy Memos service"
    echo "  all            Deploy all application services"
    echo ""
    echo "Options:"
    echo "  --force        Force recreate containers"
    echo "  --no-init      Skip initialization scripts"
    echo "  --no-network   Skip automatic network connection"
    echo "  --check        Just check service status"
    echo "  --info         Show service info without deploying"
    echo ""
    echo "Examples:"
    echo "  $0 wikijs                    # Deploy Wiki.js with network automation"
    echo "  $0 wikijs --force           # Force recreate Wiki.js containers"
    echo "  $0 memos --check            # Check Memos status"
    echo "  $0 filebrowser --info       # Show File Browser info"
}

# Function to validate service name
validate_service() {
    local service=$1
    local valid_services="filebrowser syncthing wikijs memos all"
    
    if [[ ! $valid_services =~ $service ]]; then
        log_error "Invalid service: $service"
        echo ""
        show_usage
        exit 1
    fi
}

# Function to get service info
get_service_info() {
    local service=$1
    
    case $service in
        "filebrowser")
            echo "Service: File Browser"
            echo "URL: http://files.home.lab"
            echo "Container: filebrowser_1"
            echo "Purpose: Web-based file management with TrueNAS integration"
            echo "Compose: applications/filebrowser.yml"
            echo "Init Script: init/filebrowser-init.sh"
            ;;
        "syncthing")
            echo "Service: Syncthing"  
            echo "URL: http://sync.home.lab"
            echo "Container: syncthing_1"
            echo "Purpose: Cross-device file synchronization"
            echo "Compose: applications/syncthing.yml"
            echo "Init Script: init/syncthing-init.sh"
            ;;
        "wikijs")
            echo "Service: Wiki.js"
            echo "URL: http://docs.home.lab"
            echo "Container: wikijs_1"
            echo "Purpose: Documentation and knowledge management"
            echo "Compose: applications/wikijs.yml"
            echo "Init Script: init/wikijs-init.sh"
            echo "Database: PostgreSQL (wikijs database)"
            ;;
        "memos")
            echo "Service: Memos"
            echo "URL: http://notes.home.lab"
            echo "Container: memos_1"
            echo "Purpose: Quick note capture and idea management"
            echo "Compose: applications/memos.yml"
            echo "Init Script: init/memos-init.sh"
            echo "Database: PostgreSQL (memos database)"
            ;;
    esac
}

# Function to check service status
check_service_status() {
    local service=$1
    
    echo ""
    log "🔍 Checking status for $service"
    echo ""
    
    # Get service info
    get_service_info "$service"
    echo ""
    
    # Container status
    case $service in
        "filebrowser")
            container="filebrowser"
            url="http://files.home.lab"
            ;;
        "syncthing")
            container="syncthing"
            url="http://sync.home.lab"
            ;;
        "wikijs")
            container="wikijs"
            url="http://docs.home.lab"
            ;;
        "memos")
            container="memos"
            url="http://notes.home.lab"
            ;;
    esac
    
    # Check container status
    if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
        status=$(docker ps --filter "name=$container" --format "{{.Status}}")
        log "✅ Container Status: $status"
    else
        log_error "❌ Container not running"
    fi
    
    # Check networks
    if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
        # Check Traefik network - use a simpler approach that works reliably
        if docker network inspect infrastructure_traefik | grep -q "\"Name\": \"$container\""; then
            log "✅ Connected to Traefik network"
        else
            log_warn "⚠️ NOT connected to Traefik network"
        fi
        
        # Check database network for services that need it
        case $service in
            "wikijs"|"memos")
                if docker network inspect infrastructure_database | grep -q "\"Name\": \"$container\""; then
                    log "✅ Connected to Database network"
                else
                    log_warn "⚠️ NOT connected to Database network"
                fi
                ;;
        esac
    fi
    
    # Check URL accessibility
    log_info "Testing URL accessibility..."
    if curl -f -s --max-time 5 "$url" >/dev/null 2>&1; then
        log "✅ Service accessible at $url"
    else
        log_error "❌ Service NOT accessible at $url"
    fi
    
    # Service-specific checks
    case $service in
        "wikijs")
            if curl -s --max-time 5 "$url/graphql" 2>/dev/null | grep -q "GET query missing"; then
                log "✅ GraphQL API responding"
            else
                log_warn "⚠️ GraphQL API not responding properly"
            fi
            ;;
        "memos")
            if curl -s --max-time 5 "$url/api/v1/status" >/dev/null 2>&1; then
                log "✅ API responding"
            else
                log_warn "⚠️ API not responding properly"
            fi
            ;;
    esac
    
    echo ""
}

# Function to run service initialization
run_service_init() {
    local service=$1
    
    if [ "$SKIP_INIT" = "true" ]; then
        log_info "Skipping initialization (--no-init flag)"
        return 0
    fi
    
    local init_script="$SCRIPTS_DIR/init/$service-init.sh"
    
    if [ -f "$init_script" ]; then
        log "🔧 Running initialization script for $service"
        echo ""
        
        if bash "$init_script"; then
            echo ""
            log "✅ Initialization completed"
        else
            echo ""
            log_error "❌ Initialization failed"
            echo ""
            log_warn "You may need to run this manually:"
            log_warn "bash $init_script"
            read -p "Continue with deployment anyway? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        log_info "No initialization script found ($init_script)"
    fi
}

# Function to connect service to networks automatically
connect_service_networks() {
    local service=$1
    
    if [ "$SKIP_NETWORK" = "true" ]; then
        log_info "Skipping network connection (--no-network flag)"
        echo ""
        log_warn "Remember to manually connect to Traefik network:"
        log_warn "docker network connect infrastructure_traefik ${service}_1"
        return 0
    fi
    
    # Determine container name
    local container_name="$service"
    
    log "🔗 Connecting $container_name to required networks..."
    
    # Wait for container to be ready (with timeout)
    log_info "Waiting for container to be ready..."
    local max_attempts=15
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
            log "✅ Container $container_name is ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "❌ Container $container_name did not start within expected time"
            log_warn "You may need to check the container logs:"
            log_warn "docker logs $container_name"
            return 1
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    echo ""
    
    # Connect to Traefik network if not already connected
    if ! docker network inspect infrastructure_traefik | grep -q "\"Name\": \"$container_name\""; then
        log_info "Connecting $container_name to Traefik network..."
        if docker network connect infrastructure_traefik "$container_name"; then
            log "✅ Successfully connected to Traefik network"
        else
            log_error "❌ Failed to connect to Traefik network"
            log_warn "Try manually: docker network connect infrastructure_traefik $container_name"
            return 1
        fi
    else
        log_info "Already connected to Traefik network"
    fi
    
    # Connect to database network if service needs it
    case $service in
        "wikijs"|"memos")
            if ! docker network inspect infrastructure_database | grep -q "\"Name\": \"$container_name\""; then
                log_info "Connecting $container_name to Database network..."
                if docker network connect infrastructure_database "$container_name"; then
                    log "✅ Successfully connected to Database network"
                else
                    log_warn "⚠️ Failed to connect to Database network (may still work)"
                fi
            else
                log_info "Already connected to Database network"
            fi
            ;;
    esac
    
    echo ""
}

# Function to quick health check
quick_health_check() {
    local service=$1
    
    # Define service URL
    local url=""
    case $service in
        "filebrowser")
            url="http://files.home.lab"
            ;;
        "syncthing")
            url="http://sync.home.lab"
            ;;
        "wikijs")
            url="http://docs.home.lab"
            ;;
        "memos")
            url="http://notes.home.lab"
            ;;
    esac
    
    log_info "Quick health check at $url..."
    
    # Give the service a moment if it was just deployed
    sleep 5
    
    if curl -f -s --max-time 10 "$url" >/dev/null 2>&1; then
        log "✅ Service is accessible"
        return 0
    else
        log_warn "⚠️ Service not yet accessible (may need more time)"
        log_info "You can check manually: curl -f $url"
        return 1
    fi
}

# Function to deploy a single service
deploy_single_service() {
    local service=$1
    
    echo ""
    log "🚀 Deploying $service"
    echo ""
    
    # Show service info
    get_service_info "$service"
    echo ""
    
    # Run initialization
    run_service_init "$service"
    echo ""
    
    # Determine compose file location
    local compose_file="$DOCKER_COMPOSE_DIR/applications/$service.yml"
    
    if [ ! -f "$compose_file" ]; then
        log_error "❌ Compose file not found: $compose_file"
        exit 1
    fi
    
    # Validate compose file syntax
    log_info "Validating compose file syntax..."
    if docker compose -f "$compose_file" config >/dev/null 2>&1; then
        log "✅ Compose file syntax is valid"
    else
        log_error "❌ Invalid compose file syntax"
        log_warn "Check the compose file: $compose_file"
        exit 1
    fi
    
    echo ""
    
    # Deploy the service
    if [ "$FORCE_RECREATE" = "true" ]; then
        log "🛑 Force stopping $service for recreation"
        docker compose -f "$compose_file" down
        echo ""
    fi
    
    log "📦 Starting $service containers..."
    if docker compose -f "$compose_file" up -d; then
        log "✅ Containers started successfully"
    else
        log_error "❌ Failed to start containers"
        exit 1
    fi
    
    echo ""
    
    # Connect to required networks  
    connect_service_networks "$service"
    
    # Wait a bit for service startup
    if [ "$service" = "wikijs" ]; then
        log_info "Wiki.js needs additional startup time..."
        sleep 15
    elif [ "$service" = "memos" ]; then
        log_info "Memos needs additional startup time..." 
        sleep 8
    fi
    
    # Quick health check
    quick_health_check "$service"
    
    echo ""
    log "🎉 Deployment of $service completed"
    log_info "Access at: $(get_service_url $service)"
    echo ""
}

# Function to get service URL
get_service_url() {
    local service=$1
    case $service in
        "filebrowser") echo "http://files.home.lab" ;;
        "syncthing") echo "http://sync.home.lab" ;;
        "wikijs") echo "http://docs.home.lab" ;;
        "memos") echo "http://notes.home.lab" ;;
    esac
}

# Function to deploy all services
deploy_all_services() {
    log "🚀 Deploying all application services"
    echo ""
    
    local services=("filebrowser" "syncthing" "wikijs" "memos")
    
    for service in "${services[@]}"; do
        deploy_single_service "$service"
        
        # Pause between services
        if [ "$service" != "memos" ]; then
            echo ""
            log_info "Pausing 5 seconds before next service..."
            sleep 5
        fi
    done
    
    echo ""
    log "🎉 All services deployment completed"
    echo ""
    log "Service URLs:"
    for service in "${services[@]}"; do
        echo "  • $service: $(get_service_url $service)"
    done
    echo ""
}

# Main execution
main() {
    # Parse command line arguments
    SERVICE=""
    FORCE_RECREATE="false"
    SKIP_INIT="false"
    SKIP_NETWORK="false"
    CHECK_ONLY="false"
    INFO_ONLY="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_RECREATE="true"
                shift
                ;;
            --no-init)
                SKIP_INIT="true"
                shift
                ;;
            --no-network)
                SKIP_NETWORK="true"
                shift
                ;;
            --check)
                CHECK_ONLY="true"
                shift
                ;;
            --info)
                INFO_ONLY="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$SERVICE" ]; then
                    SERVICE="$1"
                else
                    log_error "Multiple services specified"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check if service is specified
    if [ -z "$SERVICE" ]; then
        log_error "No service specified"
        echo ""
        show_usage
        exit 1
    fi
    
    # Validate service
    validate_service "$SERVICE"
    
    # Handle info-only mode
    if [ "$INFO_ONLY" = "true" ]; then
        echo ""
        log "ℹ️ Service Information for $SERVICE"
        echo ""
        get_service_info "$SERVICE"
        echo ""
        exit 0
    fi
    
    # Handle check-only mode
    if [ "$CHECK_ONLY" = "true" ]; then
        if [ "$SERVICE" = "all" ]; then
            services=("filebrowser" "syncthing" "wikijs" "memos")
            for service in "${services[@]}"; do
                check_service_status "$service"
                echo "---"
            done
        else
            check_service_status "$SERVICE"
        fi
        exit 0
    fi
    
    # Basic checks
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        exit 1
    fi
    
    if ! docker network inspect infrastructure_traefik >/dev/null 2>&1; then
        log_error "Traefik network not found. Deploy infrastructure first."
        exit 1
    fi
    
    # Deploy service(s)
    if [ "$SERVICE" = "all" ]; then
        deploy_all_services
    else
        deploy_single_service "$SERVICE"
    fi
}

# Execute main function with all arguments
main "$@"
