#!/bin/bash

# Traffic Spike Simulation Script
# This script simulates a sudden increase in traffic to the khazna-images service

set -e

NAMESPACE="khazna-images-ns"
SERVICE="khazna-images"
LOG_FILE="traffic-spike-$(date +%Y%m%d-%H%M%S).log"
CONCURRENT_REQUESTS=50
DURATION=300  # 5 minutes

echo "=== Traffic Spike Simulation ===" | tee -a $LOG_FILE
echo "Timestamp: $(date)" | tee -a $LOG_FILE
echo "Namespace: $NAMESPACE" | tee -a $LOG_FILE
echo "Service: $SERVICE" | tee -a $LOG_FILE
echo "Concurrent Requests: $CONCURRENT_REQUESTS" | tee -a $LOG_FILE
echo "Duration: $DURATION seconds" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Function to check pod status and scaling
check_scaling() {
    log "Checking pod status and scaling..."
    kubectl get pods -n $NAMESPACE -l app=khazna-images | tee -a $LOG_FILE
    
    if kubectl get hpa khazna-images-hpa -n $NAMESPACE &>/dev/null; then
        kubectl get hpa khazna-images-hpa -n $NAMESPACE | tee -a $LOG_FILE
    else
        log "HPA not found for khazna-images"
    fi
    echo "" | tee -a $LOG_FILE
}

# Function to check resource usage
check_resources() {
    log "Checking resource usage..."
    kubectl top pods -n $NAMESPACE --no-headers | grep khazna-images | tee -a $LOG_FILE || log "Resource metrics not available"
    echo "" | tee -a $LOG_FILE
}

# Function to test service response
test_service_response() {
    local test_name=$1
    log "Testing service response: $test_name"
    
    if kubectl get svc khazna-images -n $NAMESPACE &>/dev/null; then
        kubectl port-forward -n $NAMESPACE svc/khazna-images 8082:5000 &
        PORT_FORWARD_PID=$!
        sleep 5
        
        # Test health endpoint
        HEALTH_START=$(date +%s%N)
        if curl -s http://localhost:8082/health &>/dev/null; then
            HEALTH_END=$(date +%s%N)
            HEALTH_TIME=$(( (HEALTH_END - HEALTH_START) / 1000000 ))
            log "Health check: PASSED (${HEALTH_TIME}ms)"
        else
            log "Health check: FAILED"
        fi
        
        # Test API endpoint
        API_START=$(date +%s%N)
        if curl -s http://localhost:8082/api/images/stats &>/dev/null; then
            API_END=$(date +%s%N)
            API_TIME=$(( (API_END - API_START) / 1000000 ))
            log "API response: PASSED (${API_TIME}ms)"
        else
            log "API response: FAILED"
        fi
        
        kill $PORT_FORWARD_PID 2>/dev/null || true
    else
        log "Service not found"
    fi
    echo "" | tee -a $LOG_FILE
}

# Function to generate load
generate_load() {
    log "Starting load generation with $CONCURRENT_REQUESTS concurrent requests..."
    
    # Start port forwarding in background
    kubectl port-forward -n $NAMESPACE svc/khazna-images 8082:5000 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    # Create a simple load generation script
    cat > /tmp/load_test.sh << 'EOF'
#!/bin/bash
URL=$1
REQUESTS=$2
for i in $(seq 1 $REQUESTS); do
    curl -s "$URL" > /dev/null &
done
wait
EOF
    chmod +x /tmp/load_test.sh
    
    # Generate load for specified duration
    END_TIME=$(($(date +%s) + DURATION))
    while [ $(date +%s) -lt $END_TIME ]; do
        # Generate requests to different endpoints
        /tmp/load_test.sh "http://localhost:8082/health" 10 &
        /tmp/load_test.sh "http://localhost:8082/api/images/stats" 15 &
        /tmp/load_test.sh "http://localhost:8082/api/images" 25 &
        
        sleep 5
    done
    
    # Wait for all background jobs to complete
    wait
    
    # Cleanup
    kill $PORT_FORWARD_PID 2>/dev/null || true
    rm -f /tmp/load_test.sh
    
    log "Load generation completed"
}

# Function to monitor during load
monitor_during_load() {
    log "Monitoring system during load test..."
    
    # Monitor for the duration of the load test
    END_TIME=$(($(date +%s) + DURATION))
    CHECKPOINT=1
    
    while [ $(date +%s) -lt $END_TIME ]; do
        log "Load test checkpoint $CHECKPOINT"
        
        # Check pod count
        POD_COUNT=$(kubectl get pods -n $NAMESPACE -l app=khazna-images --no-headers | wc -l)
        log "Current pod count: $POD_COUNT"
        
        # Check HPA status
        if kubectl get hpa khazna-images-hpa -n $NAMESPACE &>/dev/null; then
            HPA_STATUS=$(kubectl get hpa khazna-images-hpa -n $NAMESPACE --no-headers | awk '{print $3"/"$4" targets, "$5" replicas"}')
            log "HPA status: $HPA_STATUS"
        fi
        
        # Check resource usage
        kubectl top pods -n $NAMESPACE --no-headers | grep khazna-images | head -3 | tee -a $LOG_FILE || log "Resource metrics not available"
        
        CHECKPOINT=$((CHECKPOINT + 1))
        sleep 30
    done
}

# Main simulation steps
log "Starting traffic spike simulation..."
echo "" | tee -a $LOG_FILE

# Step 1: Check initial state
log "Step 1: Checking initial system state"
check_scaling
check_resources
test_service_response "baseline"

# Step 2: Start load generation in background
log "Step 2: Starting traffic spike simulation"
generate_load &
LOAD_PID=$!

# Step 3: Monitor during load
monitor_during_load

# Step 4: Wait for load generation to complete
log "Step 4: Waiting for load generation to complete..."
wait $LOAD_PID

# Step 5: Monitor immediate post-load state
log "Step 5: Checking immediate post-load state"
check_scaling
check_resources
test_service_response "post-load"

# Step 6: Monitor scale-down process
log "Step 6: Monitoring scale-down process (10 minutes)..."
for i in {1..20}; do
    sleep 30
    log "Scale-down checkpoint $i/20"
    POD_COUNT=$(kubectl get pods -n $NAMESPACE -l app=khazna-images --no-headers | wc -l)
    log "Current pod count: $POD_COUNT"
    
    if kubectl get hpa khazna-images-hpa -n $NAMESPACE &>/dev/null; then
        HPA_STATUS=$(kubectl get hpa khazna-images-hpa -n $NAMESPACE --no-headers | awk '{print $3"/"$4" targets, "$5" replicas"}')
        log "HPA status: $HPA_STATUS"
    fi
done
echo "" | tee -a $LOG_FILE

# Step 7: Check final state
log "Step 7: Checking final system state"
check_scaling
check_resources
test_service_response "final"

# Step 8: Generate summary
log "Step 8: Generating simulation summary"
echo "" | tee -a $LOG_FILE
log "=== SIMULATION SUMMARY ==="
log "Traffic spike simulation completed successfully"
log "Key observations:"
log "- Traffic spike was generated for $DURATION seconds with $CONCURRENT_REQUESTS concurrent requests"
log "- HPA should have detected increased load and scaled up pods"
log "- Service should have maintained responsiveness during the spike"
log "- System should have scaled down after the load subsided"
log "- Check Prometheus/Grafana for detailed metrics during the test"
echo "" | tee -a $LOG_FILE

log "Simulation log saved to: $LOG_FILE"
log "Traffic spike simulation completed!"

# Cleanup
unset PORT_FORWARD_PID LOAD_PID

