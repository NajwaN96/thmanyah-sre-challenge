# Failure Simulation Scenarios

This document outlines the failure simulation scenarios designed to test the resilience and recovery capabilities of the Thmanyah microservices architecture. Each scenario is designed to simulate real-world failure conditions and validate the system's ability to maintain service availability and recover gracefully.

## Scenario 1: Database Outage Simulation

### Description
This scenario simulates a complete PostgreSQL database failure to test how the `thmanyah-api` service handles database connectivity issues and how Kubernetes responds to the failure.

### Expected Behavior
- The `thmanyah-api` service should detect the database failure through health checks
- Kubernetes should mark the pods as unhealthy and stop routing traffic to them
- Prometheus should trigger alerts for database connectivity issues
- The system should recover automatically once the database is restored

### Implementation
The database failure is simulated by scaling down the PostgreSQL deployment to zero replicas, effectively making the database unavailable.

### Recovery Process
1. Database becomes unavailable
2. API health checks fail
3. Kubernetes stops routing traffic to unhealthy pods
4. Alerts are triggered in Prometheus/Alertmanager
5. Database is restored by scaling back up
6. Services automatically reconnect and resume normal operation

## Scenario 2: Authentication Service Crash

### Description
This scenario simulates a crash in the `musahha-auth` service to test service isolation and the impact on dependent services.

### Expected Behavior
- The `musahha-auth` service pods should be restarted by Kubernetes
- The `thmanyah-api` service should handle authentication failures gracefully
- HPA should scale up additional replicas if needed
- Alerts should be triggered for service unavailability

### Implementation
The service crash is simulated by forcefully terminating pods or introducing a fatal error in the application.

### Recovery Process
1. Service crashes or becomes unresponsive
2. Kubernetes detects the failure through liveness probes
3. Failed pods are terminated and new ones are started
4. Load balancer redistributes traffic to healthy pods
5. Service availability is restored

## Scenario 3: Traffic Spike to Image Service

### Description
This scenario simulates a sudden increase in traffic to the `khazna-images` service to test auto-scaling capabilities and performance under load.

### Expected Behavior
- HPA should detect increased CPU/memory usage
- Additional pods should be automatically spawned
- Load should be distributed across all available pods
- Response times should remain within acceptable limits
- System should scale down after the traffic spike subsides

### Implementation
Traffic spike is simulated using load testing tools that generate concurrent requests to the image service endpoints.

### Recovery Process
1. Traffic spike begins
2. CPU/memory usage increases
3. HPA triggers scaling up of pods
4. New pods are started and begin handling requests
5. Load is distributed across all pods
6. After traffic subsides, HPA scales down excess pods

## Monitoring and Alerting During Failures

Each failure scenario is monitored through:
- Prometheus metrics collection
- Grafana dashboard visualization
- Alertmanager notifications
- Kubernetes event logging

## Success Criteria

For each scenario, success is measured by:
- Automatic detection of the failure
- Appropriate alerting and notification
- Graceful degradation of service
- Automatic recovery without manual intervention
- Minimal impact on overall system availability

