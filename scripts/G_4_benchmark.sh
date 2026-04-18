#!/bin/bash
# scripts/G_4_benchmark.sh <cni_name> [mode/flag]

CNI=$1
ARG2=$2
RESULTS_BASE=${RESULTS_BASE:-result_baseline}

# Parse Mode and Flags
SETUP_ONLY=false
RUN_ONLY=false
MODE="default"

if [ "$ARG2" == "--setup-only" ]; then
    SETUP_ONLY=true
elif [ "$ARG2" == "--run-only" ]; then
    RUN_ONLY=true
elif [ -n "$ARG2" ]; then
    MODE=$ARG2
fi

# Define RESULTS_DIR based on CNI and Mode (unless overwritten by environment)
if [[ $RESULTS_BASE == *"rules_"* ]]; then
    # Module 2 specific case where G_4_run_module2.sh overrides RESULTS_BASE
    RESULTS_DIR="$RESULTS_BASE"
else
    RESULTS_DIR="$RESULTS_BASE/${CNI}_${MODE}"
fi
CLUSTER_NAME="cni-$CNI"

SetupCluster() {
    echo "--- Setup Phase for $CNI ---"
    echo "Tearing down old clusters..."
    kind delete clusters --all || true
    docker network prune -f || true
    echo "Waiting 60s for deep stabilization..."
    sleep 60
    
    echo "Creating cluster: $CLUSTER_NAME..."
    MAX_RETRIES=3
    for i in $(seq 1 $MAX_RETRIES); do
        if kind create cluster --name $CLUSTER_NAME --config kind-config.yaml; then
            break
        fi
        echo "Cluster creation failed, retrying in 60s... ($i/$MAX_RETRIES)"
        kind delete clusters --all || true
        docker network prune -f || true
        sleep 60
        if [ $i -eq $MAX_RETRIES ]; then echo "Failed to create cluster. Exiting."; exit 1; fi
    done
    echo "Waiting 90s for node stabilization..."
    sleep 90
    
    echo "Restoring CNI plugins..."
    NODES=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}")
    for node in $NODES; do
      docker exec $node curl -sL -o /tmp/cni-plugins.tgz https://github.com/containernetworking/plugins/releases/download/v1.4.1/cni-plugins-linux-amd64-v1.4.1.tgz
      docker exec $node tar -C /opt/cni/bin -xzf /tmp/cni-plugins.tgz
      docker exec $node rm /tmp/cni-plugins.tgz
      # Cleanup lingering interfaces
      docker exec $node ip link delete flannel.1 2>/dev/null || true
      docker exec $node ip link delete cali0 2>/dev/null || true
    done
}

InstallCNI() {
    echo "--- Installing $CNI ($MODE) ---"
    case $CNI in
        flannel)
            curl -sL -o G_4_kube-flannel.yml https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/G_4_kube-flannel.yml
            [ "$MODE" == "hostgw" ] && sed -i 's/"Type": "vxlan"/"Type": "host-gw"/' G_4_kube-flannel.yml
            kubectl apply -f G_4_kube-flannel.yml
            # Wait for DS to appear
            for i in {1..12}; do if kubectl get daemonset -n kube-flannel kube-flannel-ds &>/dev/null; then break; fi; sleep 5; done
            kubectl wait --for=condition=Ready pod -n kube-flannel -l k8s-app=flannel --timeout=300s
            ;;
        calico)
            kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
            curl -sL -o G_4_calico-cr.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml
            sed -i 's/192.168.0.0\/16/10.244.0.0\/16/g' G_4_calico-cr.yaml
            sed -i '/kind: Installation/,/spec:/ s/spec:/spec:\n  registry: quay.io/' G_4_calico-cr.yaml
            [ "$MODE" == "bgp" ] && sed -i 's/encapsulation: IPIP/encapsulation: None/' G_4_calico-cr.yaml
            kubectl apply -f G_4_calico-cr.yaml
            # Wait for calico-node pods to appear
            echo "Waiting for calico-node pods to appear..."
            for i in {1..24}; do
                if kubectl get pods -n calico-system -l k8s-app=calico-node 2>/dev/null | grep -q "Running"; then break; fi
                sleep 5
            done
            kubectl wait --for=condition=Ready pod -n calico-system -l k8s-app=calico-node --timeout=300s
            ;;
        cilium)
            NODES=$(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}")
            for node in $NODES; do docker exec $node mount bpffs /sys/fs/bpf -t bpf || true; done
            if [ "$MODE" == "native" ]; then
                bin/G_4_cilium install --wait --set routingMode=native --set autoDirectNodeRoutes=true --set ipv4NativeRoutingCIDR=10.244.0.0/16
            else
                bin/G_4_cilium install --wait
            fi
            ;;
    esac
    sleep 30
}

SetupWorkload() {
    echo "--- Deploying Workload ---"
    ALL_NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    NODEARRAY=($ALL_NODES)
    SERVER_NODE=${NODEARRAY[0]}
    CLIENT_NODE=${NODEARRAY[1]:-${NODEARRAY[0]}}
    
    kubectl taint nodes $SERVER_NODE node-role.kubernetes.io/control-plane:NoSchedule- || true
    # Patch Server Image to Quay, but keep Client as Netshoot for diagnostics
    sed "0,/kubernetes.io\/hostname:.*/s//kubernetes.io\/hostname: $SERVER_NODE/" manifests/G_4_iperf3.yaml > manifests/G_4_temp.yaml
    sed "0,/kubernetes.io\/hostname: $SERVER_NODE/! s/kubernetes.io\/hostname:.*/kubernetes.io\/hostname: $CLIENT_NODE/" manifests/G_4_temp.yaml > manifests/G_4_temp2.yaml
    # Only replace the server image
    sed -e 's|networkstatic/iperf3|quay.io/networkstatic/iperf3|g' \
        -e '/app: iperf3-server/,/image:/ s|image: .*|image: quay.io/networkstatic/iperf3|' \
        -e '/app: iperf3-server/,/args:/ s|args: .*|args: ["-s"]|' \
        manifests/G_4_temp2.yaml > manifests/G_4_iperf3_patched.yaml

    kubectl apply -f manifests/G_4_iperf3_patched.yaml
    kubectl wait --for=condition=Ready pod -l app=iperf3-server --timeout=180s
    kubectl wait --for=condition=Ready pod -l app=iperf3-client --timeout=180s
}

RunBenchmark() {
    mkdir -p $RESULTS_DIR
    SERVER_IP=$(kubectl get pod -l app=iperf3-server -o jsonpath='{.items[0].status.podIP}')
    CLIENT_POD=$(kubectl get pod -l app=iperf3-client -o jsonpath='{.items[0].metadata.name}')
    
    echo "Running Benchmark (45s) in $RESULTS_DIR..."
    perf stat -a -e cycles,instructions,cpu-clock -o $RESULTS_DIR/G_4_perf_cycles.txt sleep 45 &
    PERF_PID=$!
    kubectl exec $CLIENT_POD -- iperf3 -c $SERVER_IP -t 45 --json > $RESULTS_DIR/G_4_iperf_tcp.json || echo "{}" > $RESULTS_DIR/G_4_iperf_tcp.json
    wait $PERF_PID || true
    sleep 5
    kubectl exec $CLIENT_POD -- iperf3 -c $SERVER_IP -u -b 100M -t 45 --json > $RESULTS_DIR/G_4_iperf_udp.json || echo "{}" > $RESULTS_DIR/G_4_iperf_udp.json
    sleep 5
    kubectl exec $CLIENT_POD -- ping -c 10 $SERVER_IP > $RESULTS_DIR/G_4_ping_latency.txt || echo "Ping failed" > $RESULTS_DIR/G_4_ping_latency.txt
    docker stats --no-stream $(docker ps --format '{{.Names}}' | grep "${CLUSTER_NAME}") > $RESULTS_DIR/G_4_cpu_stats.txt
}

# Main Logic
if [ "$RUN_ONLY" == "true" ]; then
    RunBenchmark
elif [ "$SETUP_ONLY" == "true" ]; then
    SetupCluster
    InstallCNI
    SetupWorkload
else
    SetupCluster
    InstallCNI
    SetupWorkload
    RunBenchmark
    # Auto-cleanup only in full run mode to keep Module 0/1 behavior
    kind delete clusters --all
fi
