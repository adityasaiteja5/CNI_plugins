#!/bin/bash
# scripts/G_4_measure_forensics.sh - Deep Networking Forensics Suite (Patched)

RESULTS_DIR=$1
CNI=$2
MODE=$3
CLIENT_POD=$4
SERVER_IP=$5
SVC_IP=$6

mkdir -p $RESULTS_DIR

echo "--- Starting Forensics for $CNI ($MODE) ---"

# 1. Path Tracing (MTR - TCP Mode to hit ClusterIP)
echo "Tracing path to Service $SVC_IP (TCP Port 5201)..."
# BusyBox traceroute doesn't support -T, but MTR does.
kubectl exec $CLIENT_POD -- mtr --report --report-cycles 10 --tcp -P 5201 $SVC_IP > $RESULTS_DIR/G_4_path_mtr.txt

# 2. MTU Discovery (Binary Search)
echo "Discovering MTU Fragmentation Threshold..."
# We test Pod IP directly to avoid Service NAT overhead during MTU discovery
TARGET_IP=$SERVER_IP
for SIZE in 1472 1450 1440 1420 1400 1350 1300; do
    echo "Testing MTU payload $SIZE on $TARGET_IP..."
    if kubectl exec $CLIENT_POD -- ping -c 1 -M do -s $SIZE $TARGET_IP > /dev/null 2>&1; then
        echo "PASS: $SIZE"
        echo "MAX_MTU_PAYLOAD=$SIZE" > $RESULTS_DIR/G_4_mtu_result.txt
        break
    else
        echo "FAIL: $SIZE"
    fi
done

# 3. Control Plane Forensics (Routes/Rules)
echo "Capturing Host/Pod Forwarding Logic..."
kubectl exec $CLIENT_POD -- ip route show > $RESULTS_DIR/G_4_pod_routes.txt
kubectl exec $CLIENT_POD -- ip rule show > $RESULTS_DIR/G_4_pod_rules.txt
# Capture host routes (first worker)
NODE=$(kubectl get pod $CLIENT_POD -o jsonpath='{.spec.nodeName}')
docker exec $NODE ip route show > $RESULTS_DIR/G_4_host_routes.txt

# 4. TCP Stack Behavior (ss -ti)
echo "Capturing TCP Congestion Window (cwnd)..."
# Run iperf and ss in tandem
kubectl exec $CLIENT_POD -- /bin/sh -c "iperf3 -c $SVC_IP -t 5 & sleep 2; ss -ti" > $RESULTS_DIR/G_4_tcp_stats.txt

# 5. Packet Anatomy (Payload Efficiency)
echo "Capturing raw packet headers (Packet Anatomy)..."
# IMPORTANT: Run tcpdump and iperf in the SAME exec session to prevent premature termination
PCAP_FILE="/tmp/G_4_capture.pcap"
echo "Starting capture and burst..."
kubectl exec $CLIENT_POD -- /bin/sh -c "tcpdump -c 100 -i eth0 -w $PCAP_FILE tcp port 5201 & sleep 2; iperf3 -c $SVC_IP -t 3; sleep 2"
echo "Capture complete. Copying pcap..."
kubectl cp ${CLIENT_POD}:${PCAP_FILE} $RESULTS_DIR/G_4_capture.pcap

echo "--- Forensics Capture Complete for $CNI ---"
