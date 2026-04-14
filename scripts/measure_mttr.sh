#!/bin/bash
# scripts/measure_mttr.sh
# Usage: ./measure_mttr.sh <results_dir> <worker_to_kill> <service_ip>

RESULTS_DIR=$1
WORKER=$2
SVC_IP=$3
LOG_FILE="$RESULTS_DIR/heartbeat.log"
ANALYSIS_FILE="$RESULTS_DIR/mttr_analysis.txt"

mkdir -p $RESULTS_DIR

# 1. Identify Client Pod
CLIENT_POD=$(kubectl get pod -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')

echo "Monitoring connectivity to Service $SVC_IP from $CLIENT_POD..."

# 2. Start Continuous Heartbeat (Background)
# We use nc (netcat) to check TCP port 5201 with 1s timeout
# Format: [timestamp] [result]
kubectl exec $CLIENT_POD -- /bin/sh -c "while true; do echo \"\$(date +%s.%N) \$(nc -zv -w 1 $SVC_IP 5201 2>&1)\"; sleep 0.1; done" > $LOG_FILE 2>&1 &
PING_PID=$!

echo "Heartbeat started (PID: $PING_PID). Waiting 15s for baseline..."
sleep 15

# 3. Assassinate Node
echo ">>> Chaos Trigger: Killing node $WORKER..."
docker kill $WORKER

# 4. Wait for Failover
echo "Waiting 30s for recovery..."
sleep 45
kill $PING_PID || true

# 5. Analyze MTTR
echo "Analyzing packet loss..."
python3 - <<EOF
import re
import os

log_file = "$LOG_FILE"
analysis_file = "$ANALYSIS_FILE"

timestamps = []
if os.path.exists(log_file):
    with open(log_file, "r") as f:
        for line in f:
            # Matches timestamps like '1776045456.' or '1776045456.123'
            if "open" in line or "succeeded" in line:
                match = re.search(r"^(\d+\.?\d*)", line)
                if match:
                    timestamps.append(float(match.group(1)))

if len(timestamps) < 2:
    with open(analysis_file, "w") as f:
        f.write("MTTR: Measurement Failed (Insufficient heartbeats)\n")
        f.write("MTTR (Estimated): 0 ms\n")
    exit(0)

# Find the largest gap between consecutive successful timestamps
max_gap = 0
for i in range(len(timestamps) - 1):
    gap = timestamps[i+1] - timestamps[i]
    if gap > max_gap:
        max_gap = gap

# Subtract the expected 0.1s interval to get the actual downtime
downtime = max(0, max_gap - 0.1)
mttr_ms = int(downtime * 1000)

with open(analysis_file, "w") as f:
    f.write(f"Longest TCP Disconnect: {downtime:.3f} s\n")
    f.write(f"MTTR (Estimated): {mttr_ms} ms\n")
    
print(f"MTTR: {mttr_ms} ms")
EOF
