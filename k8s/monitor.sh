#!/bin/bash

POD=vllm
NAMESPACE=vllm-lab

clear

echo "============================================"
echo "🚀 AI Inference Live Dashboard"
echo "============================================"
echo ""

while true; do
  clear

  echo "============================================"
  echo "🚀 AI Inference Live Dashboard"
  echo "============================================"
  echo ""

  echo "🧠 GPU UTILIZATION"
  echo "--------------------------------------------"

  oc exec -n $NAMESPACE $POD -- nvidia-smi dmon -s pucm -c 1 2>/dev/null | tail -n 1 | awk '
  {
    printf "SM: %-5s%% | MEM: %-5s%% | ENC: %-5s%% | DEC: %-5s%%\n", $2, $3, $4, $5
  }'

  echo ""
  echo "📊 SYSTEM STATUS"
  echo "--------------------------------------------"

  POD_STATUS=$(oc get pod $POD -n $NAMESPACE --no-headers 2>/dev/null | awk '{print $3}')

  echo "Pod Status: $POD_STATUS"

  echo ""
  echo "⚡ LIVE INSIGHT"
  echo "--------------------------------------------"

  echo "→ SM ~100% means GPU saturated"
  echo "→ Lower SM means underutilized system"

  sleep 1
done
