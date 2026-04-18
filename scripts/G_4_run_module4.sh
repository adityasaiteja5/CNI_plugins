#!/bin/bash
# scripts/G_4_run_module4.sh - End-to-End Network Path Analysis Orchestrator (Patched)

set -e

# Flannel is already completed; skipping to Calico and Cilium
CNIS=("calico" "G_4_cilium")
RESULTS_DIR="results_module_4"
mkdir -p $RESULTS_DIR

for CNI in "${CNIS[@]}"; do
    echo "==========================================="
    echo "===== Starting Module 4 for $CNI ====="
    echo "==========================================="
    
    # Setup Cluster
    ./scripts/G_4_benchmark.sh $CNI --setup-only
    
    # Get client pod and IPs
    CLIENT_POD=$(kubectl get pods -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')
    SERVER_IP=$(kubectl get pods -l app=iperf3-server -o jsonpath='{.items[0].status.podIP}')
    SVC_IP=$(kubectl get svc iperf3-service -o jsonpath='{.spec.clusterIP}')
    
    # Run Forensics
    ./scripts/G_4_measure_forensics.sh "$RESULTS_DIR/$CNI" "$CNI" "default" "$CLIENT_POD" "$SERVER_IP" "$SVC_IP"
    
    # Teardown
    kind delete clusters --all
done

echo "Forensics data capture complete. Running Analysis..."
python3 scripts/G_4_analyze_forensics.py $RESULTS_DIR
