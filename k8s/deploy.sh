#!/bin/bash

set -e

# 0. Set Pre-requisite
# export HF_TOKEN=your_HuggingFace_token_here
# chmod +x deploy.sh
# ./deploy.sh


# -------------------------------

# 1. Validate token
# -------------------------------
if [ -z "$HF_TOKEN" ]; then
  echo "❌ HF_TOKEN not set"
  echo "Run: export HF_TOKEN=your_token"
  exit 1
fi

echo "🚀 Starting deployment..."

# -------------------------------
# 2. Recreate project (clean run)
# -------------------------------
oc delete project vllm-lab --ignore-not-found
sleep 5

oc new-project vllm-lab

# -------------------------------
# 3. Create secret
# -------------------------------
echo "🔐 Creating HF secret..."
oc create secret generic hf-secret \
  --from-literal=token=$HF_TOKEN

# -------------------------------
# 4. Deploy app
# -------------------------------
echo "📦 Deploying vLLM..."
oc apply -f k8s/vllm-deploy.yaml
oc apply -f k8s/service.yaml

# -------------------------------
# 5. Wait for pod
# -------------------------------
echo "⏳ Waiting for pod to be ready..."
oc wait --for=condition=ready pod/vllm --timeout=180s

# -------------------------------
# 6. Expose route
# -------------------------------
echo "🌐 Creating route..."
oc expose svc vllm

sleep 5

ROUTE=$(oc get route vllm -o jsonpath='{.spec.host}')

echo "✅ Route ready:"
echo $ROUTE

echo $ROUTE > route.txt