#!/bin/bash

# Variables
AUTOPUBLICIP="$(curl -s http://ip.codex.storage)"
LOGLEVEL=${CRAWLER_LOGLEVEL:-INFO}
PUBLICIP=${CRAWLER_PUBLICIP:-${AUTOPUBLICIP}}
METRICSADDRESS=${CRAWLER_METRICSADDRESS:-0.0.0.0}
METRICSPORT=${CRAWLER_METRICSPORT:-8008}
DATADIR=${CRAWLER_DATADIR:-crawler_data}
DISCPORT=${CRAWLER_DISCPORT:-8090}
BOOTNODES=${CRAWLER_BOOTNODES:-testnet_sprs}

DHTENABLE=${CRAWLER_DHTENABLE:-1}
STEPDELAY=${CRAWLER_STEPDELAY:-1000}
REVISITDELAY=${CRAWLER_REVISITDELAY:-60}
CHECKDELAY=${CRAWLER_CHECKDELAY:-10}
EXPIRYDELAY=${CRAWLER_EXPIRYDELAY:-1440}

MARKETPLACEENABLE=${CRAWLER_MARKETPLACEENABLE:-1}
ETHPROVIDER=${CRAWLER_ETHPROVIDER:-NULL}
MARKETPLACEADDRESS=${CRAWLER_MARKETPLACEADDRESS:-NULL}
REQUESTCHECKDELAY=${CRAWLER_REQUESTCHECKDELAY:-10}

# Marketplace address from URL
if [[ -n "${MARKETPLACE_ADDRESS_FROM_URL}" ]]; then
  WAIT=${MARKETPLACE_ADDRESS_FROM_URL_WAIT:-300}
  SECONDS=0
  SLEEP=1
  # Run and retry if fail
  while (( SECONDS < WAIT )); do
    MARKETPLACE_ADDRESS=($(curl -s -f -m 5 "${MARKETPLACE_ADDRESS_FROM_URL}"))
    # Check if exit code is 0 and returned value is not empty
    if [[ $? -eq 0 && -n "${MARKETPLACE_ADDRESS}" ]]; then
      export MARKETPLACEADDRESS="${MARKETPLACE_ADDRESS}"
      break
    else
      # Sleep and check again
      echo "Can't get Marketplace address from ${MARKETPLACE_ADDRESS_FROM_URL} - Retry in $SLEEP seconds / $((WAIT - SECONDS))"
      sleep $SLEEP
    fi
  done
fi

# Update CLI arguments
set -- "$@" --logLevel="${LOGLEVEL}" --publicIp="${PUBLICIP}" --metricsAddress="${METRICSADDRESS}" --metricsPort="${METRICSPORT}" --dataDir="${DATADIR}" --discoveryPort="${DISCPORT}" --bootNodes="${BOOTNODES}" --dhtEnable="${DHTENABLE}" --stepDelay="${STEPDELAY}" --revisitDelay="${REVISITDELAY}" --expiryDelay="${EXPIRYDELAY}" --checkDelay="${CHECKDELAY}" --marketplaceEnable="${MARKETPLACEENABLE}" --ethProvider="${ETHPROVIDER}" --marketplaceAddress="${MARKETPLACEADDRESS}" --requestCheckDelay="${REQUESTCHECKDELAY}"

# Show
echo -e "\nRun parameters:"
vars=$(env | grep "CRAWLER_" | grep -v -e "[0-9]*_SERVICE_" -e "[0-9]*_NODEPORT_")
echo -e "${vars//CRAWLER_/   - CRAWLER_}"
echo -e "   - $@\n"

# Run
exec "$@"
