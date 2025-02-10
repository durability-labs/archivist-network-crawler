#!/bin/bash

# Environment variables from files
# If set to file path, read the file and export the variables
# If set to directory path, read all files in the directory and export the variables
if [[ -n "${ENV_PATH}" ]]; then
  set -a
  [[ -f "${ENV_PATH}" ]] && source "${ENV_PATH}" || for f in "${ENV_PATH}"/*; do source "$f"; done
  set +a
fi

# Should be passed if env variable is set.
# public IP should fetch ip.codex.storage

# --logLevel=<l>          Sets log level [default: TRACE]
# --publicIp=<a>          Public IP address where this instance is reachable. [default: 45.82.185.194]
# --metricsAddress=<ip>   Listen address of the metrics server [default: 0.0.0.0]
# --metricsPort=<p>       Listen HTTP port of the metrics server [default: 8008]
# --dataDir=<dir>         Directory for storing data [default: crawler_data]
# --discoveryPort=<p>     Port used for DHT [default: 8090]
# --bootNodes=<n>         Semi-colon-separated list of Codex bootstrap SPRs [default: testnet_sprs]
# --stepDelay=<ms>        Delay in milliseconds per crawl step [default: 3000]
# --revisitDelay=<m>      Delay in minutes after which a node can be revisited [default: 1] (24h)


# Parameters
if [[ -z "${CODEX_NAT}" ]]; then
  if [[ "${NAT_IP_AUTO}" == "true" && -z "${NAT_PUBLIC_IP_AUTO}" ]]; then
    export CODEX_NAT="extip:$(hostname --ip-address)"
    echo "Private: CODEX_NAT=${CODEX_NAT}"
  elif [[ -n "${NAT_PUBLIC_IP_AUTO}" ]]; then
    # Run for 60 seconds if fail
    WAIT=120
    SECONDS=0
    SLEEP=5
    while (( SECONDS < WAIT )); do
      IP=$(curl -s -f -m 5 "${NAT_PUBLIC_IP_AUTO}")
      # Check if exit code is 0 and returned value is not empty
      if [[ $? -eq 0 && -n "${IP}" ]]; then
        export CODEX_NAT="extip:${IP}"
        echo "Public: CODEX_NAT=${CODEX_NAT}"
        break
      else
        # Sleep and check again
        echo "Can't get Public IP - Retry in $SLEEP seconds / $((WAIT - SECONDS))"
        sleep $SLEEP
      fi
    done
  fi
fi

# Stop Codex run if can't get NAT IP when requested
if [[ "${NAT_IP_AUTO}" == "true" && -z "${CODEX_NAT}" ]]; then
  echo "Can't get Private IP - Stop Codex run"
  exit 1
elif [[ -n "${NAT_PUBLIC_IP_AUTO}" && -z "${CODEX_NAT}" ]]; then
  echo "Can't get Public IP in $WAIT seconds - Stop Codex run"
  exit 1
fi

# If marketplace is enabled from the testing environment,
# The file has to be written before Codex starts.
for key in PRIV_KEY ETH_PRIVATE_KEY; do
  keyfile="private.key"
  if [[ -n "${!key}" ]]; then
    [[ "${key}" == "PRIV_KEY" ]] && echo "PRIV_KEY variable is deprecated and will be removed in the next releases, please use ETH_PRIVATE_KEY instead!"
    echo "${!key}" > "${keyfile}"
    chmod 600 "${keyfile}"
    export CODEX_ETH_PRIVATE_KEY="${keyfile}"
    echo "Private key set"
  fi
done

# Run
echo "Run Codex node"
exec "$@"
