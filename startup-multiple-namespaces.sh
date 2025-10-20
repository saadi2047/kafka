#!/bin/bash
# ------------------------------------------------------------------
# Script: startup-multiple-namespaces.sh
# Purpose: Bring up selected applications (scale back to desired replica count)
# Author: Omkar Gupta
# ------------------------------------------------------------------

# ====== USER CONFIGURATION ======
# List of namespaces to bring up
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

# Define replica count to scale up to
SCALE_TO=1

# What to scale (usually "deployments" or "statefulsets")
TARGETS="deployments"

# OpenShift CLI binary
OC_BIN="oc"

echo "==========================================="
echo " Application Startup Script "
echo "==========================================="

for ns in "${NAMESPACES[@]}"; do
  echo ""
  echo ">>> Processing namespace: $ns"

  # Confirmation before scaling up
  read -p "Are you sure you want to scale UP namespace '$ns'? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "Skipping namespace $ns..."
    continue
  fi

  # Switch to project
  $OC_BIN project "$ns" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "⚠️  Failed to switch to namespace $ns. Skipping..."
    continue
  fi

  # Extract custom deployments for this namespace
  custom_entry=$(printf "%s\n" "${CUSTOM_DEPLOYMENTS[@]}" | grep "^$ns:" || true)
  deployments_list=$(echo "$custom_entry" | cut -d':' -f2 | tr ',' ' ')

  for target in $TARGETS; do
    echo "→ Scaling up all $target in namespace $ns ..."
    for d in $deployments_list; do
      if [ -n "$d" ]; then
        echo "   - Scaling up $target/$d to $SCALE_TO"
        $OC_BIN scale $target "$d" --replicas=$SCALE_TO -n "$ns"
      fi
    done
  done

  echo "✅ Completed namespace: $ns"
  echo "-------------------------------------------"
done

echo ""
echo "🎯 All selected namespaces have been successfully scaled up to $SCALE_TO replicas."
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
