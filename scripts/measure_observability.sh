#!/bin/bash
# scripts/measure_observability.sh - Network Observability Suite

RESULTS_DIR=$1
CNI=$2
MODE=$3
CLIENT_POD=$4

mkdir -p $RESULTS_DIR

echo "--- Starting Observability Capture for $CNI ($MODE) ---"

# 1. Cilium Specific: Hubble Flows (eBPF)
if [ "$CNI" == "cilium" ]; then
    echo "Capturing Cilium Hubble Flows (eBPF)..."
    # Capture Hubble flows from the first cilium agent pod
    CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
    kubectl -n kube-system exec $CILIUM_POD -- cilium-dbg hubble observe --output json --last 100 > $RESULTS_DIR/hubble_flows.json || echo "Hubble capture failed"
    
    echo "Capturing Cilium Metrics (Prometheus format)..."
    kubectl -n kube-system exec $CILIUM_POD -- cilium-dbg metrics list > $RESULTS_DIR/cni_metrics.txt
fi

# 2. Calico Specific: Felix Metrics
if [ "$CNI" == "calico" ]; then
    echo "Capturing Calico Felix State..."
    # Felix usually exports metrics on port 9091
    # We capture the raw state from the calico-node pod
    CALICO_POD=$(kubectl -n kube-system get pods -l k8s-app=calico-node -o jsonpath='{.items[0].metadata.name}')
    kubectl -n kube-system exec $CALICO_POD -- calico-node -version > $RESULTS_DIR/cni_version.txt
    # Capture IPPool status
    kubectl get ippools > $RESULTS_DIR/ippool_status.txt || echo "No IPPools found (Calico API not initialized)"
fi

# 3. Flannel Specific: Conntrack & Bridge Stats
if [ "$CNI" == "flannel" ]; then
    echo "Capturing Flannel Conntrack & Bridge Stats..."
    NODE=$(kubectl get pod $CLIENT_POD -o jsonpath='{.spec.nodeName}')
    docker exec $NODE conntrack -L -p tcp --dport 5201 > $RESULTS_DIR/conntrack_flows.txt 2>/dev/null || echo "conntrack not available"
    docker exec $NODE brctl show > $RESULTS_DIR/bridge_stats.txt 2>/dev/null || echo "brctl not available"
fi

# 4. Global Observability: Resource Consumption (Cgroup stats)
echo "Capturing CNI Agent Resource Consumption..."
AGENT_POD=$(kubectl -n kube-system get pods -l k8s-app=$CNI-node 2>/dev/null | grep Running | head -n 1 | awk '{print $1}')
if [ -z "$AGENT_POD" ]; then
    # Fallback for Flannel/Calico naming
    AGENT_POD=$(kubectl -n kube-system get pods -l k8s-app=kube-flannel 2>/dev/null | grep Running | head -n 1 | awk '{print $1}')
    [ -z "$AGENT_POD" ] && AGENT_POD=$(kubectl -n kube-system get pods -l k8s-app=calico-node 2>/dev/null | grep Running | head -n 1 | awk '{print $1}')
fi

echo "Agent Pod: $AGENT_POD"
if [ ! -z "$AGENT_POD" ]; then
    kubectl -n kube-system top pod $AGENT_POD --containers > $RESULTS_DIR/agent_resources.txt 2>/dev/null || echo "kubectl top not available"
fi

echo "--- Observability Capture Complete for $CNI ---"
