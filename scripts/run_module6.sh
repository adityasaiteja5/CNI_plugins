#!/bin/bash
# scripts/run_module6.sh - CNI Selection Model Research Final

set -e

CNIS=("flannel" "calico" "cilium")
TOPOLOGIES=("east_west" "north_south" "sidecar" "multi_tier" "burst")
RESULTS_DIR="results_module_6"

mkdir -p $RESULTS_DIR

for CNI in "${CNIS[@]}"; do
    echo "==========================================="
    echo "===== Researching Saturation for $CNI ====="
    echo "==========================================="
    
    # 1. Setup Environment
    ./scripts/benchmark.sh $CNI --setup-only
    
    # 2. Iterate Topologies
    for TOP in "${TOPOLOGIES[@]}"; do
        ./scripts/topology_stress.sh "$CNI" "$TOP" "$RESULTS_DIR"
    done
    
    # 3. Teardown
    kind delete clusters --all
done

echo "Research Data Collection Complete. Generating Model..."
# python3 scripts/generate_selection_model.py $RESULTS_DIR
