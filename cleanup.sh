#!/bin/bash

# Thmanyah SRE Assessment Cleanup Script
# This script removes all resources created by the setup script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_FILE="cleanup-$(date +%Y%m%d-%H%M%S).log"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a $LOG_FILE
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a $LOG_FILE
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a $LOG_FILE
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a $LOG_FILE
}

# Function to confirm cleanup
confirm_cleanup() {
    echo ""
    print_warning "This will delete ALL resources created by the Thmanyah SRE assessment!"
    print_warning "This includes:"
    echo "  - All Kubernetes deployments, services, and pods"
    echo "  - All namespaces (thmanyah-api-ns, musahha-auth-ns, khazna-images-ns, monitoring)"
    echo "  - All secrets and configmaps"
    echo "  - All network policies"
    echo "  - All ingress configurations"
    echo "  - All monitoring stack components"
    echo ""
    
    read -p "Are you sure you want to proceed? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Cleanup cancelled by user"
        exit 0
    fi
}

# Function to delete monitoring stack
cleanup_monitoring() {
    print_status "Cleaning up monitoring stack..."
    
    kubectl delete -f k8s/monitoring/prometheus.yaml --ignore-not-found=true | tee -a $LOG_FILE
    kubectl delete -f k8s/monitoring/grafana.yaml --ignore-not-found=true | tee -a $LOG_FILE
    kubectl delete -f k8s/monitoring/alertmanager.yaml --ignore-not-found=true | tee -a $LOG_FILE
    
    print_success "Monitoring stack cleanup completed"
}

# Function to delete ingress
cleanup_ingress() {
    print_status "Cleaning up ingress configuration..."
    
    kubectl delete -f k8s/ingress/ingress.yaml --ignore-not-found=true | tee -a $LOG_FILE
    kubectl delete -f k8s/ingress/tls-certificate.yaml --ignore-not-found=true | tee -a $LOG_FILE
    
    print_success "Ingress cleanup completed"
}

# Function to delete network policies
cleanup_network_policies() {
    print_status "Cleaning up network policies..."
    
    kubectl delete -f k8s/network-policies.yaml --ignore-not-found=true | tee -a $LOG_FILE
    
    print_success "Network policies cleanup completed"
}

# Function to delete services
cleanup_services() {
    print_status "Cleaning up microservices..."
    
    kubectl delete -f k8s/deployments/thmanyah-api.yaml --ignore-not-found=true | tee -a $LOG_FILE
    kubectl delete -f k8s/deployments/musahha-auth.yaml --ignore-not-found=true | tee -a $LOG_FILE
    kubectl delete -f k8s/deployments/khazna-images.yaml --ignore-not-found=true | tee -a $LOG_FILE
    
    print_success "Services cleanup completed"
}

# Function to delete database
cleanup_database() {
    print_status "Cleaning up database..."
    
    kubectl delete -f k8s/deployments/postgresql.yaml --ignore-not-found=true | tee -a $LOG_FILE
    
    print_success "Database cleanup completed"
}

# Function to delete secrets
cleanup_secrets() {
    print_status "Cleaning up secrets..."
    
    kubectl delete -f k8s/secrets/database-secret.yaml --ignore-not-found=true | tee -a $LOG_FILE
    
    print_success "Secrets cleanup completed"
}

# Function to delete namespaces
cleanup_namespaces() {
    print_status "Cleaning up namespaces..."
    
    # Delete namespaces (this will also delete all resources within them)
    kubectl delete namespace thmanyah-api-ns --ignore-not-found=true | tee -a $LOG_FILE
    kubectl delete namespace musahha-auth-ns --ignore-not-found=true | tee -a $LOG_FILE
    kubectl delete namespace khazna-images-ns --ignore-not-found=true | tee -a $LOG_FILE
    kubectl delete namespace monitoring --ignore-not-found=true | tee -a $LOG_FILE
    
    # Wait for namespaces to be fully deleted
    print_status "Waiting for namespaces to be fully deleted..."
    
    for ns in thmanyah-api-ns musahha-auth-ns khazna-images-ns monitoring; do
        while kubectl get namespace $ns &> /dev/null; do
            print_status "Waiting for namespace $ns to be deleted..."
            sleep 5
        done
    done
    
    print_success "Namespaces cleanup completed"
}

# Function to cleanup Docker images (optional)
cleanup_docker_images() {
    print_status "Cleaning up Docker images..."
    
    read -p "Do you want to remove the Docker images as well? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        docker rmi thmanyah-api:latest --force 2>/dev/null || print_warning "thmanyah-api image not found"
        docker rmi musahha-auth:latest --force 2>/dev/null || print_warning "musahha-auth image not found"
        docker rmi khazna-images:latest --force 2>/dev/null || print_warning "khazna-images image not found"
        
        print_success "Docker images cleanup completed"
    else
        print_status "Docker images cleanup skipped"
    fi
}

# Function to verify cleanup
verify_cleanup() {
    print_status "Verifying cleanup..."
    
    echo "" | tee -a $LOG_FILE
    print_status "=== CLEANUP VERIFICATION ===" | tee -a $LOG_FILE
    
    # Check if namespaces still exist
    print_status "Checking for remaining namespaces:" | tee -a $LOG_FILE
    REMAINING_NS=$(kubectl get namespaces | grep -E "(thmanyah|musahha|khazna|monitoring)" || true)
    if [ -z "$REMAINING_NS" ]; then
        print_success "No project namespaces found - cleanup successful"
    else
        print_warning "Some namespaces may still exist:"
        echo "$REMAINING_NS" | tee -a $LOG_FILE
    fi
    
    # Check for any remaining resources
    print_status "Checking for any remaining project resources:" | tee -a $LOG_FILE
    REMAINING_RESOURCES=$(kubectl get all -A | grep -E "(thmanyah|musahha|khazna)" || true)
    if [ -z "$REMAINING_RESOURCES" ]; then
        print_success "No project resources found - cleanup successful"
    else
        print_warning "Some resources may still exist:"
        echo "$REMAINING_RESOURCES" | tee -a $LOG_FILE
    fi
    
    print_success "Cleanup verification completed"
}

# Function to display cleanup summary
display_cleanup_summary() {
    print_status "=== CLEANUP SUMMARY ==="
    echo ""
    echo "The following components have been removed:"
    echo "✓ All microservices (thmanyah-api, musahha-auth, khazna-images)"
    echo "✓ PostgreSQL database"
    echo "✓ Monitoring stack (Prometheus, Grafana, Alertmanager)"
    echo "✓ Network policies and security configurations"
    echo "✓ Ingress and TLS certificates"
    echo "✓ All secrets and configmaps"
    echo "✓ All namespaces"
    echo ""
    echo "The following files remain unchanged:"
    echo "- Source code in services/ directory"
    echo "- Kubernetes manifests in k8s/ directory"
    echo "- Monitoring configurations in monitoring/ directory"
    echo "- Failure simulation scripts in failure-simulations/ directory"
    echo "- Setup and cleanup scripts in scripts/ directory"
    echo ""
    print_success "Cleanup completed successfully!"
}

# Main execution
main() {
    echo "=== Thmanyah SRE Assessment Cleanup ===" | tee $LOG_FILE
    echo "Started at: $(date)" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    
    confirm_cleanup
    
    print_status "Starting cleanup process..."
    
    cleanup_monitoring
    cleanup_ingress
    cleanup_network_policies
    cleanup_services
    cleanup_database
    cleanup_secrets
    cleanup_namespaces
    cleanup_docker_images
    verify_cleanup
    
    echo "" | tee -a $LOG_FILE
    print_success "=== CLEANUP COMPLETED SUCCESSFULLY ==="
    echo "Cleanup log saved to: $LOG_FILE"
    
    display_cleanup_summary
}

# Run main function
main "$@"

