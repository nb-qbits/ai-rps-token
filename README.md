# 🚀 AI Inference GPU Dashboard

Spin up a full AI inference system on OpenShift and visualize GPU utilization, throughput, and scaling behavior in minutes.

---

## ⚡ Quick Start (Recommended)

```bash
$git clone https://github.com/nb-qbits/ai-rps-token.git
$cd ai-rps-token

$oc login <your-cluster>

$export HF_TOKEN=your_huggingface_token
$cd ai-rps-token/k8s

### 2. Install dependencies
$pip install -r ../requirements.txt

### 3. Login to OpenShift
$oc login <cluster-url>

### 4. Set HuggingFace token
$export HF_TOKEN=your_token

### 5. Run demo
$./k8s/run-demo.sh

### 6. Launch dashboard
streamlit run ./k8s/dashboard.py
