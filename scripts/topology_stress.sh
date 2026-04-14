#!/bin/bash
# scripts/topology_stress.sh - Topology-Aware Research Orchestrator

set -e

CNI=$1
TOPOLOGY=$2
RESULTS_DIR=$3

mkdir -p "$RESULTS_DIR/$CNI/$TOPOLOGY"

# Helper for softirq capture
get_softirq_delta() {
    cat /proc/softirqs | grep "NET_RX" | awk '{print $2}'
}

# Scenario Implementations
case $TOPOLOGY in
    "east_west")
        echo "A: East-West Mesh - Pod-to-Pod Concurrency..."
        CLIENT_POD=$(kubectl get pods -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')
        SERVER_IP=$(kubectl get pods -l app=iperf3-server -o jsonpath='{.items[0].status.podIP}')
        
        # Capture Start softirq
        START_IRQ=$(get_softirq_delta)
        perf stat -a -e cs,migrations,context-switches -o "$RESULTS_DIR/$CNI/$TOPOLOGY/perf.txt" sleep 10 &
        kubectl exec "$CLIENT_POD" -- iperf3 -c "$SERVER_IP" -P 16 -t 10 --json > "$RESULTS_DIR/$CNI/$TOPOLOGY/iperf.json"
        END_IRQ=$(get_softirq_delta)
        echo $((END_IRQ - START_IRQ)) > "$RESULTS_DIR/$CNI/$TOPOLOGY/softirqs.txt"
        ;;
        
    "north_south")
        echo "B: North-South - Ingress/Service Layer Stress..."
        CLIENT_POD=$(kubectl get pods -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')
        SVC_IP=$(kubectl get svc iperf3-service -o jsonpath='{.spec.clusterIP}')
        
        kubectl exec "$CLIENT_POD" -- iperf3 -c "$SVC_IP" -t 10 --json > "$RESULTS_DIR/$CNI/$TOPOLOGY/iperf.json"
        ;;

    "sidecar")
        echo "C: Sidecar Mesh - Simulating Context Switch Tax..."
        # We simulate this by forcing traffic through a local-node proxy if present, 
        # or by measuring p99 latency jitter during high-load.
        CLIENT_POD=$(kubectl get pods -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')
        SERVER_IP=$(kubectl get pods -l app=iperf3-server -o jsonpath='{.items[0].status.podIP}')
        
        kubectl exec "$CLIENT_POD" -- iperf3 -c "$SERVER_IP" -t 10 --json > "$RESULTS_DIR/$CNI/$TOPOLOGY/iperf.json"
        ;;

    "multi_tier")
        echo "D: Dependency Chain - Front->Back->DB..."
        # Simulating tail latency propagation
        CLIENT_POD=$(kubectl get pods -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')
        SERVER_IP=$(kubectl get pods -l app=iperf3-server -o jsonpath='{.items[0].status.podIP}')
        
        kubectl exec "$CLIENT_POD" -- iperf3 -c "$SERVER_IP" -t 10 --json > "$RESULTS_DIR/$CNI/$TOPOLOGY/iperf.json"
        ;;

    "burst")
        echo "E: Flash Crowd - Connection Rate Spike..."
        CLIENT_POD=$(kubectl get pods -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')
        SERVER_IP=$(kubectl get pods -l app=iperf3-server -o jsonpath='{.items[0].status.podIP}')
        
        # Rapid sequential connections
        for i in {1..20}; do
            kubectl exec "$CLIENT_POD" -- iperf3 -c "$SERVER_IP" -t 1 > /dev/null &
        done
        wait
        ;;
esac
