#!/bin/bash
# scripts/G_6_run_all.sh

CNIS=("flannel" "calico" "G_6_cilium")
LOG_DIR="result_baseline/logs"
mkdir -p $LOG_DIR

echo "=== STARTING FULL CNI COMPARISON MATRIX ===" | tee -a $LOG_DIR/full_run.log

for cni in "${CNIS[@]}"; do
    echo "--- Benchmarking $cni ---" | tee -a $LOG_DIR/full_run.log
    bash scripts/G_6_benchmark.sh $cni 2>&1 | tee "$LOG_DIR/${cni}_exec.log"
    echo "--- Finished $cni ---" | tee -a $LOG_DIR/full_run.log
done

echo "Generating visualizations..."
python3 G_6_plots.py | tee -a $LOG_DIR/full_run.log

echo "=== ALL BENCHMARKS COMPLETE ===" | tee -a $LOG_DIR/full_run.log
