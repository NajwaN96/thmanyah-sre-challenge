#!/bin/bash

# Database Outage Simulation Script
# This script simulates a PostgreSQL database failure by scaling down the deployment

set -e

NAMESPACE="thmanyah-api-ns"
DEPLOYMENT="postgresql"
LOG_FILE="database-outage-$(date +%Y%m%d-%H%M%S).log"

echo "=== Database Outage Simulation ===" | tee -a $LOG_FILE
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
    kubectl get pods -n $NAMESPACE -l app=postgresql | tee -a $LOG_FILE
    kubectl get pods -n $NAMESPACE -l app=thmanyah-api | tee -a $LOG_FILE
    echo "" | tee -a $LOG_FILE
}

# Function to check service health
check_health() {
    log "Checking service health..."
    # Try to access the API health endpoint
    if kubectl get svc thmanyah-api -n $NAMESPACE &>/dev/null; then
        kubectl port-forward -n $NAMESPACE svc/thmanyah-api 8080:3000 &
        PORT_FORWARD_PID=$!
        sleep 5
        
        if curl -s http://localhost:8080/health &>/dev/null; then
            log "API health check: PASSED"
        else
            log "API health check: FAILED"
        fi
        
        if curl -s http://localhost:8080/ready &>/dev/null; then
            log "API readiness check: PASSED"
        else
            log "API readiness check: FAILED"
        fi
        
        kill $PORT_FORWARD_PID 2>/dev/null || true
    else
        log "Service not found"
    fi
    echo "" | tee -a $LOG_FILE
}

# Function to monitor alerts
check_alerts() {
    log "Checking for active alerts..."
    # This would typically query Prometheus/Alertmanager
    # For simulation, we'll check if the database pod is down
    DB_PODS=$(kubectl get pods -n $NAMESPACE -l app=postgresql --no-headers | wc -l)
    if [ $DB_PODS -eq 0 ]; then
        log "ALERT: Database pods are down - this should trigger alerts"
    else
        log "Database pods are running normally"
    fi
    echo "" | tee -a $LOG_FILE
}

# Main simulation steps
log "Starting database outage simulation..."
echo "" | tee -a $LOG_FILE

# Step 1: Check initial state
log "Step 1: Checking initial system state"
check_pods
check_health

# Step 2: Simulate database failure
log "Step 2: Simulating database failure by scaling down PostgreSQL deployment"
kubectl scale deployment $DEPLOYMENT -n $NAMESPACE --replicas=0 | tee -a $LOG_FILE
log "Database deployment scaled down to 0 replicas"
echo "" | tee -a $LOG_FILE

# Step 3: Wait for failure to propagate
log "Step 3: Waiting for failure to propagate (30 seconds)..."
sleep 30

# Step 4: Check system state during failure
log "Step 4: Checking system state during database outage"
check_pods
check_health
check_alerts

# Step 5: Monitor for a period
log "Step 5: Monitoring system behavior during outage (60 seconds)..."
for i in {1..6}; do
    sleep 10
    log "Monitoring checkpoint $i/6"
    kubectl get pods -n $NAMESPACE -l app=thmanyah-api --no-headers | awk '{print $1, $3}' | tee -a $LOG_FILE
done
echo "" | tee -a $LOG_FILE

# Step 6: Restore database
log "Step 6: Restoring database service"
kubectl scale deployment $DEPLOYMENT -n $NAMESPACE --replicas=1 | tee -a $LOG_FILE
log "Database deployment scaled back to 1 replica"
echo "" | tee -a $LOG_FILE

# Step 7: Wait for recovery
log "Step 7: Waiting for system recovery (60 seconds)..."
sleep 60

# Step 8: Check final state
log "Step 8: Checking final system state after recovery"
check_pods
check_health

# Step 9: Generate summary
log "Step 9: Generating simulation summary"
echo "" | tee -a $LOG_FILE
log "=== SIMULATION SUMMARY ==="
log "Database outage simulation completed successfully"
log "Key observations:"
log "- Database was successfully scaled down, simulating outage"
log "- API services should have failed health checks during outage"
log "- Database was restored and services should have recovered"
log "- Check Prometheus/Grafana for detailed metrics and alerts"
echo "" | tee -a $LOG_FILE

log "Simulation log saved to: $LOG_FILE"
log "Database outage simulation completed!"

# Cleanup
unset PORT_FORWARD_PID

