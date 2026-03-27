#!/bin/bash

ROUTE=$(oc get route vllm -n vllm-lab -o jsonpath='{.spec.host}')
URL="http://$ROUTE/v1/chat/completions"

CONCURRENCY=${CONCURRENCY:-5}
REQUESTS=${REQUESTS:-20}
PROMPT="Explain AI in simple terms with examples"

# -------------------------------
# 🔍 HEALTH CHECK FUNCTION
# -------------------------------
check_health () {

  echo ""
  echo "🔍 Checking model endpoint health..."

  RESPONSE=$(curl -s --http1.1 --no-keepalive $URL \
    -H "Content-Type: application/json" \
    -d '{
      "model": "mistralai/Mistral-7B-Instruct-v0.2",
      "messages": [{"role": "user", "content": "hello"}],
      "max_tokens": 5
    }')

  # Check if valid JSON with expected structure
  if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)

    if [[ -n "$TEXT" && "$TEXT" != "null" ]]; then
      echo "✅ Model is healthy"
      return 0
    fi
  fi

  # If we reach here → unhealthy
  echo ""
  echo "🚨 Model endpoint is NOT healthy"
  echo "----------------------------------------"
  echo "Likely causes:"
  echo "• Pod not running"
  echo "• Route not connected"
  echo "• Model container crashed"
  echo ""
  echo "🔧 Suggested fixes:"
  echo ""
  echo "1️⃣ Check pod status:"
  echo "   oc get pods -n vllm-lab"
  echo ""
  echo "2️⃣ Restart pod:"
  echo "   oc delete pod vllm -n vllm-lab"
  echo ""
  echo "3️⃣ Redeploy:"
  echo "   ./k8s/deploy.sh"
  echo ""
  echo "4️⃣ Check logs:"
  echo "   oc logs vllm -n vllm-lab"
  echo ""
  echo "----------------------------------------"
  echo "❌ Aborting benchmark"
  echo ""

  exit 1
}

# -------------------------------
# SAMPLE OUTPUT
# -------------------------------
show_sample () {

  echo ""
  echo "============================================"
  echo "🧪 Sample Request / Response"
  echo "============================================"
  echo "Prompt:"
  echo "$PROMPT"
  echo ""

  RESPONSE=$(curl -s --http1.1 --no-keepalive $URL \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"mistralai/Mistral-7B-Instruct-v0.2\",
      \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT\"}],
      \"max_tokens\": 100
    }")

  TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)

  if [[ -z "$TEXT" || "$TEXT" == "null" ]]; then
    TEXT="⚠️ Could not extract model output"
  fi

  echo "Model Output:"
  echo "$TEXT"
  echo "============================================"
  echo ""
}

# -------------------------------
# BENCHMARK FUNCTION
# -------------------------------
run_test () {
  TOKENS=$1
  TOKENS_FILE=$(mktemp)

  START=$(python3 -c 'import time; print(time.time())')

  for i in $(seq 1 $REQUESTS); do
    (
      RESPONSE=$(curl -s --http1.1 --no-keepalive $URL \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"mistralai/Mistral-7B-Instruct-v0.2\",
          \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT\"}],
          \"max_tokens\": $TOKENS
        }")

      TEXT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null)

      TOK=$(echo "$TEXT" | wc -w | tr -d ' ')

      if [[ -z "$TOK" || "$TOK" -eq 0 ]]; then
        TOK=0
      fi

      echo "$TOK" >> "$TOKENS_FILE"
    ) &

    if (( i % CONCURRENCY == 0 )); then
      wait
    fi
  done

  wait

  END=$(python3 -c 'import time; print(time.time())')
  DURATION=$(echo "$END - $START" | bc -l)

  TOTAL_TOKENS=$(awk '{s+=$1} END {print s}' "$TOKENS_FILE")
  rm -f "$TOKENS_FILE"

  TOKENS_PER_SEC=$(echo "$TOTAL_TOKENS / $DURATION" | bc -l)
  RPS=$(echo "$REQUESTS / $DURATION" | bc -l)

  echo "$TOKENS|$TOKENS_PER_SEC|$RPS|$DURATION"
}

# -------------------------------
# MAIN FLOW
# -------------------------------

check_health
show_sample

RESULT_100=$(run_test 100)
RESULT_50=$(run_test 50)

IFS="|" read -r TOK1 TPS1 RPS1 DUR1 <<< "$RESULT_100"
IFS="|" read -r TOK2 TPS2 RPS2 DUR2 <<< "$RESULT_50"

arrow () {
  awk -v a="$1" -v b="$2" 'BEGIN {
    if (b > a) print "↑";
    else if (b < a) print "↓";
    else print "-";
  }'
}

TPS_ARROW=$(arrow "$TPS1" "$TPS2")
RPS_ARROW=$(arrow "$RPS1" "$RPS2")

# -------------------------------
# FINAL OUTPUT
# -------------------------------
echo ""
echo "============================================"
echo "🚀 AI Throughput Benchmark"
echo "============================================"
echo "Config → Concurrency=$CONCURRENCY Requests=$REQUESTS"
echo ""

printf "%-12s %-15s %-15s %-10s\n" "Tokens" "Tokens/sec" "RPS" "Duration"
echo "-------------------------------------------------------------"

printf "%-12s %-15.2f %-15.2f %-10.2f\n" "100" "$TPS1" "$RPS1" "$DUR1"
printf "%-12s %-15.2f %-15.2f %-10.2f\n" "50"  "$TPS2" "$RPS2" "$DUR2"

echo ""
echo "Δ Tokens/sec: $TPS_ARROW"
echo "Δ RPS       : $RPS_ARROW"
echo "============================================"
