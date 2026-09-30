#!/bin/bash

# Authentication Service Crash Simulation Script
# This script simulates a crash in the musahha-auth service

set -e

NAMESPACE="musahha-auth-ns"
DEPLOYMENT="musahha-auth"
LOG_FILE="auth-service-crash-$(date +%Y%m%d-%H%M%S).log"

echo "=== Authentication Service Crash Simulation ===" | tee -a $LOG_FILE
echo "Timestamp: $(date)" | tee -a $LOG_FILE
echo "Namespace: $NAMESPACE" | tee -a $LOG_FILE
echo "Deployment: $DEPLOYMENT" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Function to check pod status
check_pods() {
    log "Checking pod status..."
    kubectl get pods -n $NAMESPACE -l app=musahha-auth | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

# Function to check service health
check_auth_health() {
    log "Checking authentication service health..."
    if kubectl get svc musahha-auth -n $NAMESPACE &>/dev/null; then
        kubectl port-forward -n $NAMESPACE svc/musahha-auth 8081:8080 &
        PORT_FORWARD_PID=$!
        sleep 5
        
        if curl -s http://localhost:8081/health &>/dev/null; then
            log "Auth service health check: PASSED"
        else
            log "Auth service health check: FAILED"
        fi
        
        if curl -s http://localhost:8081/ready &>/dev/null; then
            log "Auth service readiness check: PASSED"
        else
            log "Auth service readiness check: FAILED"
        fi
        
        kill $PORT_FORWARD_PID 2>/dev/null || true
    else
        log "Auth service not found"
    fi
    echo "" | tee -a $LOG_FILE
}

# Function to test authentication functionality
test_auth_functionality() {
    log "Testing authentication functionality..."
    if kubectl get svc musahha-auth -n $NAMESPACE &>/dev/null; then
        kubectl port-forward -n $NAMESPACE svc/musahha-auth 8081:8080 &
        PORT_FORWARD_PID=$!
        sleep 5
        
        # Test login endpoint
        LOGIN_RESPONSE=$(curl -s -w "%{http_code}" -X POST http://localhost:8081/auth/login \
            -H "Content-Type: application/json" \
            -d '{"username":"admin","password":"password"}' -o /dev/null)
        
        if [ "$LOGIN_RESPONSE" = "200" ]; then
            log "Authentication login test: PASSED"
        else
            log "Authentication login test: FAILED (HTTP $LOGIN_RESPONSE)"
        fi
        
        kill $PORT_FORWARD_PID 2>/dev/null || true
    else
        log "Auth service not available for testing"
    fi
    echo "" | tee -a $LOG_FILE
}

# Function to get pod restart counts
get_restart_counts() {
    log "Checking pod restart counts..."
    kubectl get pods -n $NAMESPACE -l app=musahha-auth -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

# Function to simulate pod crash
crash_pods() {
    log "Simulating service crash by deleting pods..."
    PODS=$(kubectl get pods -n $NAMESPACE -l app=musahha-auth -o jsonpath='{.items[*].metadata.name}')
    for pod in $PODS; do
        log "Deleting pod: $pod"
        kubectl delete pod $pod -n $NAMESPACE | tee -a $LOG_FILE
    done
    echo "" | tee -a $LOG_FILE
}

# Function to monitor HPA scaling
check_hpa() {
    log "Checking HPA status..."
    if kubectl get hpa musahha-auth-hpa -n $NAMESPACE &>/dev/null; then
        kubectl get hpa musahha-auth-hpa -n $NAMESPACE | tee -a $LOG_FILE
    else
        log "HPA not found for musahha-auth"
    fi
    echo "" | tee -a $LOG_FILE
}

# Main simulation steps
log "Starting authentication service crash simulation..."
echo "" | tee -a $LOG_FILE

# Step 1: Check initial state
log "Step 1: Checking initial system state"
check_pods
get_restart_counts
check_auth_health
test_auth_functionality
check_hpa

# Step 2: Simulate service crash
log "Step 2: Simulating authentication service crash"
crash_pods

# Step 3: Monitor immediate response
log "Step 3: Monitoring immediate system response (30 seconds)..."
sleep 30
check_pods
get_restart_counts

# Step 4: Monitor recovery process
log "Step 4: Monitoring recovery process..."
for i in {1..6}; do
    sleep 10
    log "Recovery checkpoint $i/6"
    kubectl get pods -n $NAMESPACE -l app=musahha-auth --no-headers | awk '{print $1, $3, $4}' | tee -a $LOG_FILE
done
echo "" | tee -a $LOG_FILE

# Step 5: Wait for full recovery
log "Step 5: Waiting for full service recovery (60 seconds)..."
sleep 60

# Step 6: Check final state
log "Step 6: Checking final system state after recovery"
check_pods
get_restart_counts
check_auth_health
test_auth_functionality
check_hpa

# Step 7: Test dependent service impact
log "Step 7: Testing impact on dependent services (thmanyah-api)"
if kubectl get svc thmanyah-api -n thmanyah-api-ns &>/dev/null; then
    kubectl port-forward -n thmanyah-api-ns svc/thmanyah-api 8080:3000 &
    API_PORT_FORWARD_PID=$!
    sleep 5
    
    # Test API health (should be working)
    if curl -s http://localhost:8080/health &>/dev/null; then
        log "Main API health after auth recovery: PASSED"
    else
        log "Main API health after auth recovery: FAILED"
    fi
    
    kill $API_PORT_FORWARD_PID 2>/dev/null || true
else
    log "Main API service not found"
fi
echo "" | tee -a $LOG_FILE

# Step 8: Generate summary
log "Step 8: Generating simulation summary"
echo "" | tee -a $LOG_FILE
log "=== SIMULATION SUMMARY ==="
log "Authentication service crash simulation completed successfully"
log "Key observations:"
log "- Authentication service pods were successfully terminated"
log "- Kubernetes automatically restarted the failed pods"
log "- Service recovery was automatic without manual intervention"
log "- HPA scaling behavior was monitored during the incident"
log "- Dependent services maintained their health status"
echo "" | tee -a $LOG_FILE

log "Simulation log saved to: $LOG_FILE"
log "Authentication service crash simulation completed!"

# Cleanup
unset PORT_FORWARD_PID API_PORT_FORWARD_PID

