#!/bin/bash
# scripts/G_4_run_module2.sh
set -e

CNIS=("calico" "G_4_cilium")
RULES=(0 100 500 1000)
FINAL_RESULTS="results_module_2"

# Ensure all stale clusters from previous failed run are gone
kind delete clusters --all || true
docker network prune -f || true
sleep 60

mkdir -p $FINAL_RESULTS/logs

for CNI in "${CNIS[@]}"; do
    echo "===== Starting Module 2 for $CNI ====="
    
    # 1. Setup Cluster + CNI + Workload
    RESULTS_BASE=$FINAL_RESULTS ./scripts/G_4_benchmark.sh $CNI --setup-only | tee $FINAL_RESULTS/logs/${CNI}_setup.log
    
    for COUNT in "${RULES[@]}"; do
        echo ">>> Scaling to $COUNT rules..."
        
        # 2. Apply Policies
        if [ $COUNT -gt 0 ]; then
            python3 scripts/generate_policies.py $COUNT > manifests/G_4_module2_policies.yaml
            kubectl apply -f manifests/G_4_module2_policies.yaml
            if [ $COUNT -ge 500 ]; then
                echo "Waiting 60s for high-density policy stabilization..."
                sleep 60
            else
                sleep 20
            fi
        fi
        
        # 3. Run Benchmark (Explicitly set results dir)
        RESULTS_BASE="$FINAL_RESULTS/$CNI/rules_$COUNT" ./scripts/G_4_benchmark.sh $CNI --run-only | tee $FINAL_RESULTS/logs/${CNI}_rules_${COUNT}.log
        
        # 4. Cleanup Policies
        if [ $COUNT -gt 0 ]; then
            kubectl delete -f manifests/G_4_module2_policies.yaml
        fi
    done
    
    # Cleanup cluster after CNI scaling is done
    kind delete clusters --all
done

echo "Module 2 Benchmarking Complete. Generating plots..."
python3 scripts/G_4_generate_plots.py $RESULTS_BASE
