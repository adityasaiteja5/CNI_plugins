#!/bin/bash
# scripts/run_module3.sh
set -e

CNIS=("flannel" "calico" "cilium")
FINAL_RESULTS="results_module_3"
mkdir -p $FINAL_RESULTS/logs

for CNI in "${CNIS[@]}"; do
    echo "===== Starting Module 3 for $CNI ====="
    
    # 1. Setup Environment
    ./scripts/benchmark.sh $CNI --setup-only | tee $FINAL_RESULTS/logs/${CNI}_setup.log
    
    # 2. Pre-load images
    echo "Pre-loading images to $CNI cluster nodes via ctr..."
    NODES=$(docker ps --filter "name=cni-$CNI" --format "{{.Names}}")
    for NODE in $NODES; do
        echo "Pulling images on $NODE..."
        docker exec $NODE ctr -n k8s.io images pull docker.io/networkstatic/iperf3 || true
        docker exec $NODE ctr -n k8s.io images pull docker.io/nicolaka/netshoot || true
    done

    # 3. Deploy 2-replica server with anti-affinity
    echo "Deploying 2-replica iperf3-server with podAntiAffinity..."
    kubectl delete deployment iperf3-server iperf3-client --ignore-not-found
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iperf3-server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: iperf3-server
  template:
    metadata:
      labels:
        app: iperf3-server
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - iperf3-server
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: iperf3-server
        image: networkstatic/iperf3
        args: ['-s']
---
apiVersion: v1
kind: Service
metadata:
  name: iperf3-service
spec:
  selector:
    app: iperf3-server
  ports:
  - protocol: TCP
    port: 5201
    targetPort: 5201
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: iperf3-client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: iperf3-client
  template:
    metadata:
      labels:
        app: iperf3-client
    spec:
      nodeSelector:
        kubernetes.io/hostname: "cni-${CNI}-control-plane"
      containers:
      - name: iperf3-client
        image: nicolaka/netshoot
        command: ["sleep", "infinity"]
EOF

    echo "Waiting for pinned pods to stabilize..."
    kubectl rollout status deployment iperf3-server
    kubectl rollout status deployment iperf3-client
    
    # 3. Get Service IP
    SVC_IP=$(kubectl get svc iperf3-service -o jsonpath='{.spec.clusterIP}')
    echo "Service IP: $SVC_IP"

    # 4. Run MTTR Measurement
    # We kill worker node 1
    RESULTS_DIR="$FINAL_RESULTS/$CNI"
    ./scripts/measure_mttr.sh $RESULTS_DIR "cni-$CNI-worker" "$SVC_IP" | tee $FINAL_RESULTS/logs/${CNI}_mttr.log
    
    # 5. Cleanup
    kind delete clusters --all
done

echo "Module 3 Complete. Generating MTTR plots..."
python3 - <<EOF
import matplotlib.pyplot as plt
import os

cnis = ["flannel", "calico", "cilium"]
mttr_data = []

for cni in cnis:
    path = f"$FINAL_RESULTS/{cni}/mttr_analysis.txt"
    if os.path.exists(path):
        with open(path, "r") as f:
            for line in f:
                if "MTTR (Estimated):" in line:
                    val_str = line.split(":")[1].replace("ms", "").strip()
                    try:
                        val = int(float(val_str))
                        mttr_data.append(val)
                    except:
                        mttr_data.append(0)
    else:
        mttr_data.append(0)

plt.figure(figsize=(10, 6))
bars = plt.bar(cnis, mttr_data, color=['grey', 'green', 'blue'])
plt.ylabel('Recovery Time (ms)')
plt.title('Module 3: Mean Time to Recovery (MTTR) Comparison')
plt.grid(axis='y', linestyle='--', alpha=0.7)

for bar in bars:
    yval = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2, yval + 50, f"{yval}ms", ha='center', va='bottom', fontweight='bold')

plt.savefig("$FINAL_RESULTS/mttr_comparison.png")
print("MTTR plot saved to $FINAL_RESULTS/mttr_comparison.png")
EOF
