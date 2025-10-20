#!/bin/bash
# ------------------------------------------------------------------
# Script: shutdown-multiple-namespaces.sh
# Purpose: Gracefully bring down selected applications (scale to 0)
# Author: Omkar Gupta
# ------------------------------------------------------------------

# ====== CONFIGURATION ======
NAMESPACES=(
  "prod-dr-admin"
  "prod-dr-frontend"
  "prod-dr-kms"
  "prod-dr-simulators"
  "prod-dr-transaction"
)

# Deployments per namespace
CUSTOM_DEPLOYMENTS=(
  "prod-dr-admin:admin-adminservice"
  "prod-dr-frontend:transactionfe-transaction-frontend"
  "prod-dr-kms:kms-kmsservice"
  "prod-dr-simulators:demo-merchantsimulator,javasimulator-javautilityapisimulator"
  "prod-dr-transaction:payment-paymentservice,txn-transactionservice"
)

SCALE_TO=0
TARGETS="deployments"
OC_BIN="oc"

echo "==========================================="
echo " Application Shutdown Script "
echo "==========================================="

for ns in "${NAMESPACES[@]}"; do
  echo ""
  echo ">>> Processing namespace: $ns"

  read -p "Are you sure you want to scale down namespace '$ns'? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "Skipping namespace $ns..."
    continue
  fi

  $OC_BIN project "$ns" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "⚠️  Failed to switch to namespace $ns. Skipping..."
    continue
  fi

  custom_entry=$(printf "%s\n" "${CUSTOM_DEPLOYMENTS[@]}" | grep "^$ns:" || true)
  deployments_list=$(echo "$custom_entry" | cut -d':' -f2 | tr ',' ' ')

  for target in $TARGETS; do
    echo "→ Scaling down $target in namespace $ns ..."
    for d in $deployments_list; do
      echo "   - Scaling down $target/$d to $SCALE_TO"
      $OC_BIN scale $target "$d" --replicas=$SCALE_TO -n "$ns"
    done
  done

  echo "✅ Completed namespace: $ns"
  echo "-------------------------------------------"
done

echo ""
echo "🎯 All selected namespaces have been processed."
# ====== STATUS CHECK SECTION ======
echo ""
echo "==========================================="
echo " Checking Deployment Status After Shutdown "
echo "==========================================="
for ns in "${NAMESPACES[@]}"; do
  echo ""
  echo ">>> Namespace: $ns"
  $OC_BIN get deploy -n "$ns"
done

echo ""
echo "✅ Status check completed for all namespaces."
