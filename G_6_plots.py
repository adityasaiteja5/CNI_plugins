import matplotlib.pyplot as plt
import numpy as np
import os

# Hardcoded data for Group 6
DATA = {
  "module0": {
    "flannel": {
      "throughput": 9.369173243356693,
      "cpu_usage": 3.1633333333333336,
      "cycles": 706.174254606,
      "latency_rtt": 0.231
    },
    "calico": {
      "throughput": 10.700475655983,
      "cpu_usage": 5.611666666666667,
      "cycles": 588.199046968,
      "latency_rtt": 0.0825111111111111
    },
    "cilium": {
      "throughput": 9.92294322419664,
      "cpu_usage": 6.016666666666667,
      "cycles": 684.377371059,
      "latency_rtt": 0.08877777777777777
    }
  },
  "module1": {
    "flannel_vxlan": {
      "throughput": 9.886369668592726,
      "cpu_usage": 3.481666666666667,
      "cycles": 576.6131992,
      "latency_rtt": 0.08851111111111111
    },
    "flannel_hostgw": {
      "throughput": 16.48840252969028,
      "cpu_usage": 3.67,
      "cycles": 521.41137979,
      "latency_rtt": 0.06224444444444445
    },
    "calico_ipip": {
      "throughput": 10.545577019683993,
      "cpu_usage": 5.34,
      "cycles": 665.834180527,
      "latency_rtt": 0.08442222222222222
    },
    "calico_bgp": {
      "throughput": 11.585262941325045,
      "cpu_usage": 6.466666666666666,
      "cycles": 503.163042325,
      "latency_rtt": 0.07531111111111112
    },
    "cilium_vxlan": {
      "throughput": 10.656484884761236,
      "cpu_usage": 6.8183333333333325,
      "cycles": 515.969320888,
      "latency_rtt": 0.08275555555555555
    },
    "cilium_native": {
      "throughput": 14.591298477271335,
      "cpu_usage": 7.765,
      "cycles": 495.389210207,
      "latency_rtt": 0.0672888888888889
    }
  },
  "module2": {
    "flannel": {
      "0": {"throughput": 9.568362725945693, "cpu_usage": 4.45, "cycles": 493.9483295, "latency_rtt": 0.221},
      "100": {"throughput": 9.181152482770127, "cpu_usage": 5.8933333333333335, "cycles": 581.242440034, "latency_rtt": 0.208},
      "500": {"throughput": 9.054906477362675, "cpu_usage": 7.088333333333334, "cycles": 565.149024002, "latency_rtt": 0.25},
      "1000": {"throughput": 9.176937900628705, "cpu_usage": 4.951666666666667, "cycles": 571.739992889, "latency_rtt": 0.259}
    },
    "calico": {
      "0": {"throughput": 11.108110731670168, "cpu_usage": 6.076666666666667, "cycles": 496.636831154, "latency_rtt": 0.15},
      "100": {"throughput": 11.171986332892427, "cpu_usage": 5.966666666666666, "cycles": 485.090018261, "latency_rtt": 0.168},
      "500": {"throughput": 10.498777218028916, "cpu_usage": 7.22, "cycles": 564.642417595, "latency_rtt": 0.147},
      "1000": {"throughput": 10.610541987011342, "cpu_usage": 5.898333333333333, "cycles": 585.159367644, "latency_rtt": 0.154}
    },
    "cilium": {
      "0": {"throughput": 10.148798887580693, "cpu_usage": 7.616666666666666, "cycles": 584.557646436, "latency_rtt": 0.194},
      "100": {"throughput": 9.247669079353425, "cpu_usage": 6.948333333333333, "cycles": 872.707980268, "latency_rtt": 0.206},
      "500": {"throughput": 10.224444358924519, "cpu_usage": 5.8066666666666675, "cycles": 581.054612181, "latency_rtt": 0.191},
      "1000": {"throughput": 10.3658181546998, "cpu_usage": 7.043333333333333, "cycles": 614.795405281, "latency_rtt": 0.208}
    }
  },
  "module3": {
    "flannel": 2900,
    "calico": 6900,
    "cilium": 8900
  }
}

def plot_module0():
    cnis = ['flannel', 'calico', 'cilium']
    metrics = ['throughput', 'cpu_usage', 'cycles', 'latency_rtt']
    titles = ['Throughput (TCP)', 'CPU Usage (Max %)', 'CPU Cycles (Giga)', 'Avg Latency (RTT)']
    units = ['Gbps', '%', 'Giga Cycles', 'ms']
    colors = ['#3498db', '#f1c40f', '#e67e22', '#9b59b6']

    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    plt.subplots_adjust(hspace=0.3, wspace=0.3)

    for i, (m, title, unit, color) in enumerate(zip(metrics, titles, units, colors)):
        row, col = i // 2, i % 2
        vals = [DATA['module0'][c][m] for c in cnis]
        axes[row, col].bar(cnis, vals, color=color)
        axes[row, col].set_title(title, fontweight='bold')
        axes[row, col].set_ylabel(unit)

    plt.suptitle('Module 0: CNI Performance Baseline Dashboard (Group 6)', fontsize=18, fontweight='bold')
    os.makedirs("results", exist_ok=True)
    plt.savefig("results/G_6_performance_matrix.png")
    print("Saved results/G_6_performance_matrix.png")

def plot_module1():
    cnis = ['flannel', 'calico', 'cilium']
    metrics = ['throughput', 'cpu_usage', 'cycles', 'latency_rtt']
    titles = ['Throughput (TCP)', 'CPU Usage (Max %)', 'CPU Cycles (Giga)', 'Avg Latency (RTT)']
    units = ['Gbps', '%', 'Giga Cycles', 'ms']
    
    x = np.arange(len(cnis))
    width = 0.35

    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    plt.subplots_adjust(hspace=0.3, wspace=0.3)

    overlay_map = {'flannel': 'flannel_vxlan', 'calico': 'calico_ipip', 'cilium': 'cilium_vxlan'}
    native_map = {'flannel': 'flannel_hostgw', 'calico': 'calico_bgp', 'cilium': 'cilium_native'}

    for i, (m, title, unit) in enumerate(zip(metrics, titles, units)):
        row, col = i // 2, i % 2
        overlay_vals = [DATA['module1'][overlay_map[c]][m] for c in cnis]
        native_vals = [DATA['module1'][native_map[c]][m] for c in cnis]

        axes[row, col].bar(x - width/2, overlay_vals, width, label='Overlay', color='#3498db')
        axes[row, col].bar(x + width/2, native_vals, width, label='Native', color='#2ecc71')
        axes[row, col].set_title(title, fontweight='bold')
        axes[row, col].set_ylabel(unit)
        axes[row, col].set_xticks(x)
        axes[row, col].set_xticklabels(cnis)
        axes[row, col].legend()

    plt.suptitle('Module 1: Internal Protocol Baseline (Overlay vs Native) - Group 6', fontsize=18, fontweight='bold')
    os.makedirs("results_module_1", exist_ok=True)
    plt.savefig("results_module_1/G_6_module1_baseline.png")
    print("Saved results_module_1/G_6_module1_baseline.png")

def plot_module2():
    cnis = ['flannel', 'calico', 'cilium']
    rules = [0, 100, 500, 1000]
    metrics = ['throughput', 'latency_rtt', 'cpu_usage', 'cycles']
    titles = ['Throughput vs Rules', 'Latency (RTT) vs Rules', 'CPU Usage vs Rules', 'CPU Cycles vs Rules']
    units = ['Gbps', 'ms', '%', 'Giga Cycles']
    colors = {'flannel': '#95a5a6', 'calico': '#27ae60', 'cilium': '#2980b9'}

    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    plt.subplots_adjust(hspace=0.3, wspace=0.3)

    for i, (m, title, unit) in enumerate(zip(metrics, titles, units)):
        row, col = i // 2, i % 2
        for cni in cnis:
            vals = [DATA['module2'][cni][str(r)][m] for r in rules]
            axes[row, col].plot(rules, vals, marker='o', label=cni, color=colors[cni], linewidth=2)
        
        axes[row, col].set_title(title, fontweight='bold')
        axes[row, col].set_xlabel('Number of NetworkPolicies')
        axes[row, col].set_ylabel(unit)
        axes[row, col].grid(True, linestyle='--', alpha=0.7)
        axes[row, col].legend()

    plt.suptitle('Module 2: High-Density Security Cost (Security Tax Scaling) - Group 6', fontsize=18, fontweight='bold')
    os.makedirs("results_module_2", exist_ok=True)
    plt.savefig("results_module_2/G_6_module2_security_tax.png")
    print("Saved results_module_2/G_6_module2_security_tax.png")

def plot_module3():
    cnis = ["flannel", "calico", "cilium"]
    mttr_data = [DATA['module3'][c] for c in cnis]

    plt.figure(figsize=(10, 6))
    bars = plt.bar(cnis, mttr_data, color=['grey', 'green', 'blue'])
    plt.ylabel('Recovery Time (ms)')
    plt.title('Module 3: Mean Time to Recovery (MTTR) Comparison - Group 6')
    plt.grid(axis='y', linestyle='--', alpha=0.7)

    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval + 50, f"{yval}ms", ha='center', va='bottom', fontweight='bold')

    os.makedirs("results_module_3", exist_ok=True)
    plt.savefig("results_module_3/G_6_mttr_comparison.png")
    print("Saved results_module_3/G_6_mttr_comparison.png")

if __name__ == "__main__":
    plot_module0()
    plot_module1()
    plot_module2()
    plot_module3()
