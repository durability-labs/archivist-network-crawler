#!/bin/bash

# Variables
AUTOPUBLICIP="$(curl -s http://ip.archivist.storage)"
LOGLEVEL=${CRAWLER_LOGLEVEL:-INFO}
PUBLICIP=${CRAWLER_PUBLICIP:-${AUTOPUBLICIP}}
METRICSADDRESS=${CRAWLER_METRICSADDRESS:-0.0.0.0}
METRICSPORT=${CRAWLER_METRICSPORT:-8008}
DATADIR=${CRAWLER_DATADIR:-crawler_data}
DISCPORT=${CRAWLER_DISCPORT:-8090}

DHTENABLE=${CRAWLER_DHTENABLE:-1}
STEPDELAY=${CRAWLER_STEPDELAY:-1000}
REVISITDELAY=${CRAWLER_REVISITDELAY:-60}
CHECKDELAY=${CRAWLER_CHECKDELAY:-10}
EXPIRYDELAY=${CRAWLER_EXPIRYDELAY:-1440}

MARKETPLACEENABLE=${CRAWLER_MARKETPLACEENABLE:-1}
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

# Optional overrides:
OPTIONALS=" "
if [[ -n "${CRAWLER_BOOTNODES}" ]]; then
  OPTIONALS+="--bootNodes=${CRAWLER_BOOTNODES} "
fi
if [[ -n "${CRAWLER_ETHPROVIDER}" ]]; then
  OPTIONALS+="--ethProvider=${CRAWLER_ETHPROVIDER} "
fi
if [[ -n "${CRAWLER_MARKETPLACEADDRESS}" ]]; then
  OPTIONALS+="--marketplaceAddress=${CRAWLER_MARKETPLACEADDRESS} "
fi

# Update CLI arguments
set -- "$@" --logLevel="${LOGLEVEL}" --publicIp="${PUBLICIP}" --metricsAddress="${METRICSADDRESS}" --metricsPort="${METRICSPORT}" --dataDir="${DATADIR}" --discoveryPort="${DISCPORT}" --dhtEnable="${DHTENABLE}" --stepDelay="${STEPDELAY}" --revisitDelay="${REVISITDELAY}" --expiryDelay="${EXPIRYDELAY}" --checkDelay="${CHECKDELAY}" --marketplaceEnable="${MARKETPLACEENABLE}" --requestCheckDelay="${REQUESTCHECKDELAY}" ${OPTIONALS}

# Show
echo -e "\nRun parameters:"
vars=$(env | grep "CRAWLER_" | grep -v -E -e "([0-9])*_SERVICE_" -e "[0-9]_NODEPORT_" -e "_PORT(_[0-9])*")
echo -e "${vars//CRAWLER_/   - CRAWLER_}"
echo -e "   - $@\n"

# Run
exec "$@"
