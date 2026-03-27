# 🚀 AI Inference GPU Dashboard

## Setup

### 1. Clone repo
git clone https://github.com/<your-username>/ai-rps-token.git
cd ai-rps-token/k8s

### 2. Install dependencies
pip install -r ../requirements.txt

### 3. Login to OpenShift
oc login <cluster-url>

### 4. Set HuggingFace token
export HF_TOKEN=your_token

### 5. Run demo
./run-demo.sh

### 6. Launch dashboard
streamlit run dashboard.py
