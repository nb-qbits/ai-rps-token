#!/bin/bash

set -e

echo "============================================"
echo "🚀 AI Inference Demo"
echo "============================================"
echo ""

# -------------------------------
# 1. Check OpenShift login
# -------------------------------
if ! oc whoami &>/dev/null; then
  echo "❌ Not logged into OpenShift"
  echo "👉 Run: oc login <cluster-url>"
  exit 1
fi

USER=$(oc whoami)
echo "✅ Logged in as: $USER"

# -------------------------------
# 2. Select project
# -------------------------------
CURRENT_NS=$(oc project -q)

echo ""
echo "📦 Current project: $CURRENT_NS"
read -p "👉 Use this project? (y/n): " USE_NS

if [[ "$USE_NS" != "y" ]]; then
  read -p "Enter project name: " NEW_NS
  oc project $NEW_NS
fi

# -------------------------------
# 3. Check GPU availability
# -------------------------------
echo ""
echo "🔍 Checking GPU availability..."

GPU=$(oc get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"' 2>/dev/null | grep -v null || true)

if [[ -z "$GPU" ]]; then
  echo "❌ No GPU detected in cluster"
  exit 1
fi

echo "✅ GPU detected"

# -------------------------------
# 4. Setup HF token
# -------------------------------
echo ""
if ! oc get secret hf-secret &>/dev/null; then
  echo "🔐 HuggingFace token required"
  read -s -p "Enter HF token: " HF_TOKEN
  echo ""

  if [[ -z "$HF_TOKEN" ]]; then
    echo "❌ HF token cannot be empty"
    exit 1
  fi

  oc create secret generic hf-secret \
    --from-literal=token=$HF_TOKEN

  echo "✅ HF secret created"
else
  echo "✅ HF token already configured"
fi

# -------------------------------
# 5. Deploy system
# -------------------------------
echo ""
echo "📦 Deploying vLLM..."

./k8s/deploy.sh

# -------------------------------
# 6. Wait for pod
# -------------------------------
echo ""
echo "⏳ Waiting for pod to be ready..."

oc wait --for=condition=Ready pod/vllm --timeout=120s

echo "✅ Pod running"

# -------------------------------
# 7. Get route
# -------------------------------
if [ ! -f route.txt ]; then
  echo "❌ route.txt missing"
  exit 1
fi

ROUTE=$(cat route.txt)
URL="http://$ROUTE/v1/chat/completions"

echo ""
echo "🌐 Route: http://$ROUTE"

# -------------------------------
# 8. WAIT FOR MODEL (IMPORTANT)
# -------------------------------
echo ""
echo "📦 Model loading into GPU memory..."
echo "🔍 Waiting for model to be ready..."

MAX_RETRIES=30
RETRY=0

while true; do
  RESPONSE=$(curl -s $URL \
    -H "Content-Type: application/json" \
    -d '{
      "model": "mistralai/Mistral-7B-Instruct-v0.2",
      "messages": [{"role": "user", "content": "hello"}],
      "max_tokens": 5
    }')

  if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)

    if [[ -n "$TEXT" && "$TEXT" != "null" ]]; then
      echo "✅ Model is ready"
      break
    fi
  fi

  RETRY=$((RETRY+1))

  if (( RETRY >= MAX_RETRIES )); then
    echo ""
    echo "⚠️ Model taking longer than expected"
    read -p "👉 Press ENTER to continue anyway or Ctrl+C to abort..."
    break
  fi

  echo "⏳ Still loading model... ($RETRY/$MAX_RETRIES)"
  sleep 5
done

# -------------------------------
# 9. Start dashboard
# -------------------------------
echo ""
echo "📊 Starting live GPU dashboard..."

./k8s/monitor.sh &
MONITOR_PID=$!

sleep 3

# -------------------------------
# 10. Run benchmark
# -------------------------------
echo ""
echo "⚙️ Running workload..."

CONCURRENCY=20 REQUESTS=80 ./k8s/test.sh

# -------------------------------
# 11. Cleanup
# -------------------------------
echo ""
echo "🛑 Stopping dashboard..."
kill $MONITOR_PID 2>/dev/null || true

echo ""
echo "============================================"
echo "🎉 Demo Complete"
echo "Run Different commands to try different loads such as: CONCURRENCY=20 REQUESTS=80 ./k8s/test.sh"
echo "You can monitor the tests by running ./k8s/monitor.sh"
echo "============================================"