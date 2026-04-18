#!/bin/bash
# scripts/G_4_run_module3.sh
set -e

CNIS=("flannel" "calico" "G_4_cilium")
FINAL_RESULTS="results_module_3"
mkdir -p $FINAL_RESULTS/logs

for CNI in "${CNIS[@]}"; do
    echo "===== Starting Module 3 for $CNI ====="
    
    # 1. Setup Environment
    ./scripts/G_4_benchmark.sh $CNI --setup-only | tee $FINAL_RESULTS/logs/${CNI}_setup.log
    
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
    ./scripts/G_4_measure_mttr.sh $RESULTS_DIR "cni-$CNI-worker" "$SVC_IP" | tee $FINAL_RESULTS/logs/${CNI}_mttr.log
    
    # 5. Cleanup
    kind delete clusters --all
done

echo "Module 3 Complete. Generating plots via standardized script..."
python3 G_4_plots.py
