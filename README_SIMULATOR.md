# CNI Simulator: Priority Tuning Guide

The **Inference Engine** uses a 1-10 scale to weigh your research priorities. Use this guide to tune your `scenario.json`:

### 1-10 Priority Scaling
- **10 (Critical)**: The CNI must excel here; failure is a deal-breaker.
- **5 (Neutral)**: Standard baseline requirement.
- **1 (Ignore)**: This metric is not a factor in your research scenario.

### Research Metrics
| Metric | Description | Arch. Example |
|--------|-------------|---------------|
| **Throughput** | Maximum Bitrate (Gbps) | High North-South ingress traffic. |
| **Latency** | p99 Packet Processing Floor | Latency-sensitive financial apps. |
| **Security** | Policy Scaling Density | Zero-trust clusters with 1000+ rules. |
| **MTTR** | Recovery/Self-Healing Speed | Spot-instance clusters with high churn. |
| **Observability**| Data-plane Introspection | eBPF Flow-capture requirements (Hubble). |
