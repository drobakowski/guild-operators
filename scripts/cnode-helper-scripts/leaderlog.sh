#!/bin/bash
# shellcheck disable=SC1090
######################################
# User Variables - Change as desired #
# Common variables set in env file   #
######################################

#POOLID=""         # Pool ID in Bech32 format (Default: derive from env)
#POOL_VRF_KEY=""   # Pool's VRF Key file (Default: derive from env)
#KOIOS_API=""       # URL to Koios API (Default: derive from env)
######################################
# Do NOT modify code below           #
######################################

if [[ -f "$(pwd)"/env ]]; then
  source "$(pwd)"/env
else
  source "$(dirname "$0")"/env
fi
epoch=$(curl -s "http://${PROM_HOST}:${PROM_PORT}/metrics" | grep -i cardano_node_metrics_epoch_int | cut -d\  -f2)
eta0=$(curl -s "${KOIOS_API}/epoch_params?select=nonce,epoch_no&epoch_no=eq.${epoch}" | jq -r .[0].nonce)
poolid="$(cat "${POOL_DIR}"/pool.id-bech32)"
epoch_stake=$(curl -fs "${KOIOS_API}/epoch_info?_epoch_no=${epoch}&select=active_stake" | jq -r .[0].active_stake 2>/dev/null)
if [[ "${epoch_stake}" == "" ]]; then
  echo "The calculation for epoch stake is still underway (which is expected right after epoch transition), please try after an hour or so"
else
  pool_stake=$(curl -sf -H "Content-Type: application/json" "${KOIOS_API}/pool_info?select=active_stake" -d '{"_pool_bech32_ids":["'"${poolid}"'"]}' | jq -r .[0].active_stake 2>/dev/null)
  if [[ "${pool_stake}" == "" ]]; then
    echo "Could not find active stake for pool ID ${poolid}!"
  else
    sigma=$(echo "${pool_stake}" "${epoch_stake}" | awk '{printf "%.20f", $1/$2}')
    echo "Checking leader logs for epoch '${epoch}' with nonce '${eta0}'"
    echo "Pool stake: ${pool_stake}, Epoch Stake (active): ${epoch_stake}, Sigma: ${sigma}"
    ./leaderLogs.py --vrf-skey $CNODE_HOME/priv/pool/$POOL_NAME/vrf.skey --pool-id $(cat $CNODE_HOME/priv/pool/$POOL_NAME/pool.id) --epoch $epoch --epoch-nonce $eta0 --sigma "${sigma}" | tee $CNODE_HOME/logs/leaderLog_${epoch}
  fi
fi
