#!/bin/bash

# Thmanyah SRE Assessment Setup Script
# This script sets up the entire microservices architecture on Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="thmanyah-sre-assessment"
LOG_FILE="setup-$(date +%Y%m%d-%H%M%S).log"

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Kubernetes cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot access Kubernetes cluster. Please ensure kubectl is configured correctly."
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to build Docker images
build_images() {
    print_status "Building Docker images..."
    
    # Build thmanyah-api image
    print_status "Building thmanyah-api image..."
    cd services/thmanyah-api
    docker build -t thmanyah-api:latest . | tee -a ../../$LOG_FILE
    cd ../..
    
    # Build musahha-auth image
    print_status "Building musahha-auth image..."
    cd services/musahha-auth
    docker build -t musahha-auth:latest . | tee -a ../../$LOG_FILE
    cd ../..
    
    # Build khazna-images image
    print_status "Building khazna-images image..."
    cd services/khazna-images
    docker build -t khazna-images:latest . | tee -a ../../$LOG_FILE
    cd ../..
    
    print_success "All Docker images built successfully"
}

# Function to create namespaces
create_namespaces() {
    print_status "Creating Kubernetes namespaces..."
    
    kubectl apply -f k8s/deployments/thmanyah-api.yaml | tee -a $LOG_FILE
    kubectl apply -f k8s/deployments/musahha-auth.yaml | tee -a $LOG_FILE
    kubectl apply -f k8s/deployments/khazna-images.yaml | tee -a $LOG_FILE
    kubectl apply -f k8s/monitoring/namespace.yaml | tee -a $LOG_FILE
    
    print_success "Namespaces created successfully"
}

# Function to deploy secrets
deploy_secrets() {
    print_status "Deploying secrets..."
    
    kubectl apply -f k8s/secrets/database-secret.yaml | tee -a $LOG_FILE
    
    print_success "Secrets deployed successfully"
}

# Function to deploy database
deploy_database() {
    print_status "Deploying PostgreSQL database..."
    
    kubectl apply -f k8s/deployments/postgresql.yaml | tee -a $LOG_FILE
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgresql -n thmanyah-api-ns --timeout=300s | tee -a $LOG_FILE
    
    print_success "Database deployed and ready"
}

# Function to deploy services
deploy_services() {
    print_status "Deploying microservices..."
    
    # Deploy thmanyah-api
    kubectl apply -f k8s/deployments/thmanyah-api.yaml | tee -a $LOG_FILE
    
    # Deploy musahha-auth
    kubectl apply -f k8s/deployments/musahha-auth.yaml | tee -a $LOG_FILE
    
    # Deploy khazna-images
    kubectl apply -f k8s/deployments/khazna-images.yaml | tee -a $LOG_FILE
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    kubectl wait --for=condition=ready pod -l app=thmanyah-api -n thmanyah-api-ns --timeout=300s | tee -a $LOG_FILE
    kubectl wait --for=condition=ready pod -l app=musahha-auth -n musahha-auth-ns --timeout=300s | tee -a $LOG_FILE
    kubectl wait --for=condition=ready pod -l app=khazna-images -n khazna-images-ns --timeout=300s | tee -a $LOG_FILE
    
    print_success "All services deployed and ready"
}

# Function to deploy network policies
deploy_network_policies() {
    print_status "Deploying network policies..."
    
    kubectl apply -f k8s/network-policies.yaml | tee -a $LOG_FILE
    
    print_success "Network policies deployed successfully"
}

# Function to deploy ingress
deploy_ingress() {
    print_status "Deploying ingress configuration..."
    
    kubectl apply -f k8s/ingress/tls-certificate.yaml | tee -a $LOG_FILE
    kubectl apply -f k8s/ingress/ingress.yaml | tee -a $LOG_FILE
    
    print_success "Ingress deployed successfully"
}

# Function to deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    
    # Deploy Prometheus
    kubectl apply -f k8s/monitoring/prometheus.yaml | tee -a $LOG_FILE
    
    # Deploy Grafana
    kubectl apply -f k8s/monitoring/grafana.yaml | tee -a $LOG_FILE
    
    # Deploy Alertmanager
    kubectl apply -f k8s/monitoring/alertmanager.yaml | tee -a $LOG_FILE
    
    # Wait for monitoring services to be ready
    print_status "Waiting for monitoring services to be ready..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s | tee -a $LOG_FILE
    kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s | tee -a $LOG_FILE
    kubectl wait --for=condition=ready pod -l app=alertmanager -n monitoring --timeout=300s | tee -a $LOG_FILE
    
    print_success "Monitoring stack deployed successfully"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    echo "" | tee -a $LOG_FILE
    print_status "=== DEPLOYMENT STATUS ===" | tee -a $LOG_FILE
    
    # Check namespaces
    print_status "Namespaces:" | tee -a $LOG_FILE
    kubectl get namespaces | grep -E "(thmanyah|musahha|khazna|monitoring)" | tee -a $LOG_FILE
    
    # Check pods in each namespace
    print_status "Pods in thmanyah-api-ns:" | tee -a $LOG_FILE
    kubectl get pods -n thmanyah-api-ns | tee -a $LOG_FILE
    
    print_status "Pods in musahha-auth-ns:" | tee -a $LOG_FILE
    kubectl get pods -n musahha-auth-ns | tee -a $LOG_FILE
    
    print_status "Pods in khazna-images-ns:" | tee -a $LOG_FILE
    kubectl get pods -n khazna-images-ns | tee -a $LOG_FILE
    
    print_status "Pods in monitoring namespace:" | tee -a $LOG_FILE
    kubectl get pods -n monitoring | tee -a $LOG_FILE
    
    # Check services
    print_status "Services:" | tee -a $LOG_FILE
    kubectl get svc -A | grep -E "(thmanyah|musahha|khazna|prometheus|grafana|alertmanager)" | tee -a $LOG_FILE
    
    # Check HPA
    print_status "Horizontal Pod Autoscalers:" | tee -a $LOG_FILE
    kubectl get hpa -A | tee -a $LOG_FILE
    
    print_success "Deployment verification completed"
}

# Function to display access information
display_access_info() {
    print_status "=== ACCESS INFORMATION ==="
    
    echo ""
    print_status "To access the services, use port forwarding:"
    echo ""
    echo "# Main API Service:"
    echo "kubectl port-forward -n thmanyah-api-ns svc/thmanyah-api 3000:3000"
    echo "Then access: http://localhost:3000"
    echo ""
    echo "# Authentication Service:"
    echo "kubectl port-forward -n musahha-auth-ns svc/musahha-auth 8080:8080"
    echo "Then access: http://localhost:8080"
    echo ""
    echo "# Images Service:"
    echo "kubectl port-forward -n khazna-images-ns svc/khazna-images 5000:5000"
    echo "Then access: http://localhost:5000"
    echo ""
    echo "# Prometheus:"
    echo "kubectl port-forward -n monitoring svc/prometheus 9090:9090"
    echo "Then access: http://localhost:9090"
    echo ""
    echo "# Grafana:"
    echo "kubectl port-forward -n monitoring svc/grafana 3001:3000"
    echo "Then access: http://localhost:3001 (admin/admin123)"
    echo ""
    echo "# Alertmanager:"
    echo "kubectl port-forward -n monitoring svc/alertmanager 9093:9093"
    echo "Then access: http://localhost:9093"
    echo ""
}

# Function to display next steps
display_next_steps() {
    print_status "=== NEXT STEPS ==="
    echo ""
    echo "1. Test the services using the port forwarding commands above"
    echo "2. Import Grafana dashboards from the grafana-dashboards/ directory"
    echo "3. Run failure simulation scenarios:"
    echo "   - ./failure-simulations/database-outage.sh"
    echo "   - ./failure-simulations/auth-service-crash.sh"
    echo "   - ./failure-simulations/traffic-spike.sh"
    echo "4. Monitor the system behavior in Grafana and Prometheus"
    echo "5. Check alerts in Alertmanager during failure scenarios"
    echo ""
}

# Main execution
main() {
    echo "=== Thmanyah SRE Assessment Setup ===" | tee $LOG_FILE
    echo "Started at: $(date)" | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
    
    check_prerequisites
    build_images
    create_namespaces
    deploy_secrets
    deploy_database
    deploy_services
    deploy_network_policies
    deploy_ingress
    deploy_monitoring
    verify_deployment
    
    echo "" | tee -a $LOG_FILE
    print_success "=== SETUP COMPLETED SUCCESSFULLY ==="
    echo "Setup log saved to: $LOG_FILE"
    
    display_access_info
    display_next_steps
}

# Run main function
main "$@"

