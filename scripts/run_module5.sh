#!/bin/bash
# scripts/run_module5.sh - Network Observability Orchestrator (Refined)

set -e

# Calico is done; focus on Cilium eBPF
CNIS=("cilium")
RESULTS_DIR="results_module_5"
mkdir -p $RESULTS_DIR

for CNI in "${CNIS[@]}"; do
    echo "==========================================="
    echo "===== Starting Module 5 for $CNI ====="
    echo "==========================================="
    
    # Setup Cluster
    ./scripts/benchmark.sh $CNI --setup-only
    
    # Get client pod
    CLIENT_POD=$(kubectl get pods -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')
    
    # Run Background Load
    echo "Starting background traffic load..."
    SVC_IP=$(kubectl get svc iperf3-service -o jsonpath='{.spec.clusterIP}')
    kubectl exec $CLIENT_POD -- iperf3 -c $SVC_IP -t 20 > /dev/null &
    
    # Run Observability Capture
    ./scripts/measure_observability.sh "$RESULTS_DIR/$CNI" "$CNI" "default" "$CLIENT_POD"
    
    # Teardown
    kind delete clusters --all
done

echo "Observability data capture complete. Running Analysis..."
