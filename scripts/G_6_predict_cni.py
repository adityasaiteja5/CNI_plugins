# scripts/G_6_predict_cni.py
import sys
import json
import os

class DeepResearchEngine:
    def __init__(self):
        # Research DNA [Throughput, Latency, Security, MTTR, Observability]
        # Derived from Module 1-6 experimental results.
        self.cni_dna = {
            "flannel": {"throughput": 8, "latency": 7, "security": 2, "mttr": 11, "obs": 2},
            "calico":  {"throughput": 10, "latency": 8, "security": 7, "mttr": 6, "obs": 6},
            "G_6_cilium":  {"throughput": 7, "latency": 10, "security": 10, "mttr": 5, "obs": 10}
        }
        self.scaling_slopes = {"flannel": 0.04, "calico": 0.02, "G_6_cilium": 0.0001}

    def print_help(self):
        print("\n[ CNI RESEARCH SIMULATOR v8.1 ]")
        print("Priority Guide (1-10): 10=Critical | 5=Neutral | 1=Ignore")
        print("-" * 50)

    def simulate(self, config):
        scores = {"flannel": 0, "calico": 0, "G_6_cilium": 0}
        projections = {}
        insights = []

        # 1. Topology Multi-Inference & Rationale
        workload = config.get('workload', {})
        topos = workload.get('topologies', [])
        for topo in topos:
            if topo == "sidecar":
                scores["G_6_cilium"] += 12
                insights.append("- Architecture: Sidecar Mesh detected. Cilium eBPF Socket-Redirect win confirmed.")
            elif topo == "burst":
                scores["calico"] += 6
                scores["G_6_cilium"] += 6
                insights.append("- Stability: Traffic Burst detected. Calico/Cilium eBPF-driven scaling prioritised.")
            elif topo == "east_west":
                scores["flannel"] += 5
                insights.append("- Workflow: Internal East-West traffic. Minimal encapsulation overhead is optimal.")
            elif topo == "north_south":
                scores["calico"] += 8
                insights.append("- Workflow: North-South Ingress. Calico standard BGP routing provides maximum bit-rate.")

        # 2. Priority Weighting
        priorities = config.get('research_priorities', {})
        for cni in scores:
            for p, weight in priorities.items():
                if p in self.cni_dna[cni]:
                    # Generate Rationale for high priorities
                    if weight > 8:
                        insights.append(f"- Research Priority: Critical need for {p.upper()}. Advancing {cni.capitalize()}.")
                    scores[cni] += self.cni_dna[cni][p] * weight

        # 3. Scaling & Hardware Saturation
        policies = workload.get('num_policies', 0)
        hardware = config.get('hardware_profile', {})
        ram = hardware.get('system_ram_gb', 16)
        
        for cni in scores:
            lat = self.cni_dna[cni]["latency"] * 0.1
            slope_penalty = policies * self.scaling_slopes[cni]
            total_lat = lat + slope_penalty
            
            # Saturation Check (Research Module 2/6 Saturation Boundary)
            hw_limit = (ram / 16) * 1000
            if policies > hw_limit and cni != "G_6_cilium":
                scores[cni] -= 40
                insights.append(f"- Saturation: {cni.capitalize()} has hit the ‘Iptables Wall’ on your {ram}GB RAM.")
            
            projections[cni] = total_lat

        return sorted(scores.items(), key=lambda x: x[1], reverse=True), projections, insights

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 G_6_predict_cni.py <scenario.json>")
        sys.exit(1)

    try:
        if not os.path.exists(sys.argv[1]):
            print(f"Error: File {sys.argv[1]} not found.")
            sys.exit(1)

        with open(sys.argv[1], 'r') as f:
            config = json.load(f)
        
        engine = DeepResearchEngine()
        engine.print_help()
        
        results, projections, insights = engine.simulate(config)

        print("=" * 70)
        print(f"      SCENARIO: {config.get('scenario_name', 'Unnamed Research Scenario')}")
        print("=" * 70)
        
        print(f"\nWINNING DATA-PLANE: {results[0][0].upper()}")
        print("-" * 70)
        
        print("COMPATIBILITY SCORECARD:")
        max_score = results[0][1]
        for cni, score in results:
            pct = (score / max_score) * 100 if max_score > 0 else 0
            print(f"- {cni.ljust(8)}: {int(score)} pts ({pct:.1f}%)")

        print("\nLATENCY PROJECTION (ms):")
        for cni, lat in projections.items():
            bar = "█" * int(lat * 5)
            print(f"- {cni.ljust(8)} | {bar} {lat:.3f}ms")

        print("\nTOPOLOGY & SCALE INSIGHTS (Deep Kernel Rationale):")
        for note in sorted(list(set(insights))):
            print(note)
        
        print("\nFINAL RESEARCH CONCLUSION:")
        winner = results[0][0]
        if winner == "flannel":
            print("Flannel is selected due to unparalleled MTTR and zero-encapsulation simplicity.")
        elif winner == "calico":
            print("Calico is selected for its high-throughput BGP peering and ingress stability.")
        else:
            print("Cilium is selected for its high-density eBPF O(1) architectural supremacy.")
        print("=" * 70 + "\n")

    except Exception as e:
        print(f"Engine Error: {e}")

if __name__ == "__main__":
    main()
