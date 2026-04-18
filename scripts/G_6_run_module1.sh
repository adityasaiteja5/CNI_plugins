#!/bin/bash
# scripts/G_6_run_module1.sh

MODES=(
    "cilium vxlan"
    "cilium native"
)

export RESULTS_BASE="results_module_1"
LOG_DIR="$RESULTS_BASE/logs"
mkdir -p $LOG_DIR

echo "=== STARTING MODULE 1: INTERNAL PROTOCOL BASELINES ===" | tee -a $LOG_DIR/G_6_module1_run.log
echo "Objective: Compare CPU Instruction Cost of Overlay vs Native Routing" | tee -a $LOG_DIR/G_6_module1_run.log

for entry in "${MODES[@]}"; do
    read -r cni mode <<< "$entry"
    echo "--- Benchmarking $cni in mode: $mode ---" | tee -a $LOG_DIR/G_6_module1_run.log
    bash scripts/G_6_benchmark.sh $cni $mode 2>&1 | tee "$LOG_DIR/${cni}_${mode}_exec.log"
    echo "--- Finished $cni ($mode) ---" | tee -a $LOG_DIR/G_6_module1_run.log
done

echo "Generating comparative visualizations..."
python3 scripts/G_6_generate_plots.py | tee -a $LOG_DIR/G_6_module1_run.log

echo "=== MODULE 1 BENCHMARKS COMPLETE ===" | tee -a $LOG_DIR/G_6_module1_run.log
