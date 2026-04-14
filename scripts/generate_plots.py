import matplotlib.pyplot as plt
import json
import os
import re

def parse_iperf_json(filepath):
    """Parse iperf3 JSON output for multiple metrics."""
    try:
        if not os.path.exists(filepath):
            return {}
        with open(filepath, 'r') as f:
            data = json.load(f)
            if "end" in data:
                end = data["end"]
                res = {}
                # Handle both TCP and UDP variants of summary keys
                summary = end.get("sum_received", end.get("sum", {}))
                
                if "bits_per_second" in summary:
                    res["throughput"] = summary["bits_per_second"] / 1e9
                
                if "retransmits" in end.get("sum_sent", {}):
                    res["retransmits"] = end["sum_sent"]["retransmits"]
                
                if "jitter_ms" in summary:
                    res["jitter"] = summary["jitter_ms"]
                    res["lost_percent"] = summary.get("lost_percent", 0)
                elif "sum" in end and "jitter_ms" in end["sum"]: # Alternate UDP location
                    res["jitter"] = end["sum"]["jitter_ms"]
                    res["lost_percent"] = end["sum"].get("lost_percent", 0)

                # RTT fallback from intervals (iperf3 RTT is in microseconds)
                if "intervals" in data:
                    rtts = [stream["rtt"] for interval in data["intervals"] for stream in interval["streams"] if "rtt" in stream]
                    if rtts:
                        res["avg_rtt_ms"] = (sum(rtts) / len(rtts)) / 1000.0
                
                return res
    except Exception as e:
        print(f"Error parsing {filepath}: {e}")
    return {}

def parse_cpu_stats(filepath):
    """Extract CPU percentage from docker stats output."""
    try:
        if not os.path.exists(filepath):
            return 0
        with open(filepath, 'r') as f:
            content = f.read()
            # Find percentages like "15.5%"
            percentages = re.findall(r"(\d+\.\d+)%", content)
            if percentages:
                # Returns the average of worker nodes
                return sum(float(p) for p in percentages) / len(percentages)
    except Exception:
        pass
    return 0

def parse_cycles(filepath):
    """Extract total CPU cycles from perf stat output."""
    try:
        if not os.path.exists(filepath):
            return 0
        with open(filepath, 'r') as f:
            for line in f:
                if "cycles" in line:
                    # Match comma-separated or plain numbers
                    match = re.search(r"([\d,]+)\s+cycles", line)
                    if match:
                        return int(match.group(1).replace(',', ''))
    except Exception:
        pass
    return 0

def parse_ping_latency(filepath):
    """Extract average RTT from ping output."""
    try:
        if not os.path.exists(filepath):
            return 0
        with open(filepath, 'r') as f:
            content = f.read()
            # Match rtt min/avg/max/mdev = 0.543/0.678/0.890/0.120 ms
            match = re.search(r"rtt min/avg/max/mdev = [\d.]+/(?P<avg>[\d.]+)/[\d.]+/.+", content)
            if match:
                return float(match.group("avg"))
    except Exception:
        pass
    return 0

def generate_module0():
    """Module 0: Performance accountability baseline (Flannel vs Calico vs Cilium defaults)."""
    base = os.getenv('RESULTS_BASE', 'results')
    cnis = ['flannel', 'calico', 'cilium']
    metrics = ['throughput', 'lost_percent', 'jitter', 'cpu_usage', 'cycles', 'latency_rtt']
    results = {cni: {m: 0 for m in metrics} for cni in cnis}
    
    for cni in cnis:
        tcp_path = f"{base}/{cni}/iperf_tcp.json"
        udp_path = f"{base}/{cni}/iperf_udp.json"
        cpu_path = f"{base}/{cni}/cpu_stats.txt"
        cycles_path = f"{base}/{cni}/perf_cycles.txt"
        ping_path = f"{base}/{cni}/ping_latency.txt"
        
        tcp_m = parse_iperf_json(tcp_path)
        udp_m = parse_iperf_json(udp_path)
        cpu_val = parse_cpu_stats(cpu_path)
        cycles_val = parse_cycles(cycles_path)
        ping_val = parse_ping_latency(ping_path)
        
        results[cni]['throughput'] = tcp_m.get("throughput", 0)
        results[cni]['lost_percent'] = udp_m.get("lost_percent", 0)
        results[cni]['jitter'] = udp_m.get("jitter", 0)
        results[cni]['cpu_usage'] = cpu_val
        results[cni]['cycles'] = cycles_val / 1e9
        results[cni]['latency_rtt'] = ping_val if ping_val > 0 else tcp_m.get("avg_rtt_ms", 0)

    fig, axes = plt.subplots(3, 2, figsize=(15, 18))
    plt.subplots_adjust(hspace=0.4, wspace=0.3)
    
    plot_configs = [
        ('throughput', 'Throughput (TCP)', 'Gbps', '#3498db'),
        ('lost_percent', 'Packet Loss (UDP)', '%', '#e74c3c'),
        ('jitter', 'Jitter (UDP)', 'ms', '#2ecc71'),
        ('latency_rtt', 'Avg Latency (RTT)', 'ms', '#9b59b6'),
        ('cpu_usage', 'CPU Usage (Max %)', '%', '#f1c40f'),
        ('cycles', 'CPU Cycles (Total)', 'Giga Cycles', '#e67e22')
    ]
    
    for i, (metric, title, ylabel, color) in enumerate(plot_configs):
        row, col = i // 2, i % 2
        axes[row, col].bar(cnis, [results[c][metric] for c in cnis], color=color)
        axes[row, col].set_title(title, fontweight='bold')
        axes[row, col].set_ylabel(ylabel)

    plt.suptitle('Module 0: CNI Performance Baseline Dashboard', fontsize=18, fontweight='bold')
    plt.savefig(f"{base}/performance_matrix.png")
    print(f"Module 0 dashboard saved to {base}/performance_matrix.png")

def generate_module1():
    """Module 1: Internal Protocol Baseline (Overlay vs Native)."""
    base = os.getenv('RESULTS_BASE', 'results_module_1')
    runs = [
        ('flannel', 'vxlan'), ('flannel', 'hostgw'),
        ('calico', 'ipip'), ('calico', 'bgp'),
        ('cilium', 'vxlan'), ('cilium', 'native')
    ]
    
    metrics = ['throughput', 'lost_percent', 'jitter', 'cpu_usage', 'cycles', 'latency_rtt']
    results = {f"{c}_{m}": {met: 0 for met in metrics} for c, m in runs}
    
    for cni, mode in runs:
        run_id = f"{cni}_{mode}"
        tcp_path = f"{base}/{run_id}/iperf_tcp.json"
        udp_path = f"{base}/{run_id}/iperf_udp.json"
        cpu_path = f"{base}/{run_id}/cpu_stats.txt"
        cycles_path = f"{base}/{run_id}/perf_cycles.txt"
        ping_path = f"{base}/{run_id}/ping_latency.txt"
        
        tcp_m = parse_iperf_json(tcp_path)
        udp_m = parse_iperf_json(udp_path)
        cpu_val = parse_cpu_stats(cpu_path)
        cycles_val = parse_cycles(cycles_path)
        ping_val = parse_ping_latency(ping_path)
        
        results[run_id]['throughput'] = tcp_m.get("throughput", 0)
        results[run_id]['lost_percent'] = udp_m.get("lost_percent", 0)
        results[run_id]['jitter'] = udp_m.get("jitter", 0)
        results[run_id]['cpu_usage'] = cpu_val
        results[run_id]['cycles'] = cycles_val / 1e9
        results[run_id]['latency_rtt'] = ping_val if ping_val > 0 else tcp_m.get("avg_rtt_ms", 0)

    fig, axes = plt.subplots(3, 2, figsize=(15, 20))
    plt.subplots_adjust(hspace=0.4, wspace=0.3)
    
    cnis = ['flannel', 'calico', 'cilium']
    x = [0, 1, 2]
    width = 0.35
    
    plot_configs = [
        ('throughput', 'Throughput (TCP)', 'Gbps', '#3498db', '#2980b9'),
        ('lost_percent', 'Packet Loss (UDP)', '%', '#e74c3c', '#c0392b'),
        ('jitter', 'Jitter (UDP)', 'ms', '#2ecc71', '#27ae60'),
        ('latency_rtt', 'Avg Latency (RTT)', 'ms', '#9b59b6', '#8e44ad'),
        ('cpu_usage', 'CPU Usage (Max %)', '%', '#f1c40f', '#f39c12'),
        ('cycles', 'CPU Cycles (Total)', 'Giga Cycles', '#e67e22', '#d35400')
    ]
    
    for i, (metric, title, ylabel, color_over, color_nat) in enumerate(plot_configs):
        row, col = i // 2, i % 2
        overlay_key = f"flannel_vxlan" if metric == 'cycles' else f"flannel_vxlan" # Dummy if needed
        # Robust key selection for Overlay vs Native
        overlay_map = {'flannel': 'flannel_vxlan', 'calico': 'calico_ipip', 'cilium': 'cilium_vxlan'}
        native_map = {'flannel': 'flannel_hostgw', 'calico': 'calico_bgp', 'cilium': 'cilium_native'}
        
        overlay_vals = [results.get(overlay_map[c], {metric:0})[metric] for c in cnis]
        native_vals = [results.get(native_map[c], {metric:0})[metric] for c in cnis]
        
        axes[row, col].bar([p - width/2 for p in x], overlay_vals, width, label='Overlay', color=color_over)
        axes[row, col].bar([p + width/2 for p in x], native_vals, width, label='Native', color=color_nat)
        axes[row, col].set_title(title, fontweight='bold')
        axes[row, col].set_ylabel(ylabel)
        axes[row, col].set_xticks(x)
        axes[row, col].set_xticklabels(cnis)
        axes[row, col].legend()

    plt.suptitle('Module 1: Internal Protocol Baseline (Overlay vs Native)', fontsize=20, fontweight='bold')
    plt.savefig(f"{base}/module1_baseline.png")
    print(f"Module 1 dashboard saved to {base}/module1_baseline.png")

def generate_module2():
    """Module 2: High-Density Security Cost (Scaling Rules)."""
    base = os.getenv('RESULTS_BASE', 'results_module_2')
    cnis = ['flannel', 'calico', 'cilium']
    rules = [0, 100, 500, 1000]
    
    metrics = ['throughput', 'cpu_usage', 'cycles', 'latency_rtt']
    # results[cni][rule_count][metric]
    results = {cni: {r: {m: 0 for m in metrics} for r in rules} for cni in cnis}
    
    for cni in cnis:
        for r in rules:
            run_path = f"{base}/{cni}/rules_{r}"
            tcp_path = f"{run_path}/iperf_tcp.json"
            cpu_path = f"{run_path}/cpu_stats.txt"
            cycles_path = f"{run_path}/perf_cycles.txt"
            ping_path = f"{run_path}/ping_latency.txt"
            
            tcp_m = parse_iperf_json(tcp_path)
            results[cni][r]['throughput'] = tcp_m.get("throughput", 0)
            results[cni][r]['cpu_usage'] = parse_cpu_stats(cpu_path)
            results[cni][r]['cycles'] = parse_cycles(cycles_path) / 1e9
            results[cni][r]['latency_rtt'] = parse_ping_latency(ping_path)

    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    plt.subplots_adjust(hspace=0.3, wspace=0.3)
    
    colors = {'flannel': '#95a5a6', 'calico': '#27ae60', 'cilium': '#2980b9'}
    plot_configs = [
        ('throughput', 'Throughput vs Rule Count', 'Gbps'),
        ('latency_rtt', 'Latency (RTT) vs Rule Count', 'ms'),
        ('cpu_usage', 'CPU Usage vs Rule Count', '%'),
        ('cycles', 'CPU Cycles vs Rule Count', 'Giga Cycles')
    ]
    
    for i, (metric, title, ylabel) in enumerate(plot_configs):
        row, col = i // 2, i % 2
        for cni in cnis:
            vals = [results[cni][r][metric] for r in rules]
            axes[row, col].plot(rules, vals, marker='o', label=cni, color=colors[cni], linewidth=2)
        
        axes[row, col].set_title(title, fontweight='bold')
        axes[row, col].set_xlabel('Number of NetworkPolicies')
        axes[row, col].set_ylabel(ylabel)
        axes[row, col].grid(True, linestyle='--', alpha=0.7)
        axes[row, col].legend()

    plt.suptitle('Module 2: High-Density Security Cost (Security Tax Scaling)', fontsize=18, fontweight='bold')
    plt.savefig(f"{base}/module2_security_tax.png")
    print(f"Module 2 dashboard saved to {base}/module2_security_tax.png")

if __name__ == "__main__":
    if "results_module_2" in os.getenv('RESULTS_BASE', ''):
        generate_module2()
    elif "results_module_1" in os.getenv('RESULTS_BASE', ''):
        generate_module1()
    else:
        # Default fallback or selective run
        if os.path.exists("results_module_2"): generate_module2()
        if os.path.exists("results_module_1"): generate_module1()
        if os.path.exists("results"): generate_module0()
