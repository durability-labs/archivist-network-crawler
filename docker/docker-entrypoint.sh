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
STEPDELAY=${CRAWLER_STEPDELAY:-1000}
CHECKDELAY=${CRAWLER_CHECKDELAY:-10}
EXPIRYDELAY=${CRAWLER_EXPIRYDELAY:-60}

# Update CLI arguments
set -- "$@" --logLevel="${LOGLEVEL}" --publicIp="${PUBLICIP}" --metricsAddress="${METRICSADDRESS}" --metricsPort="${METRICSPORT}" --dataDir="${DATADIR}" --discoveryPort="${DISCPORT}" --bootNodes="${BOOTNODES}" --stepDelay="${STEPDELAY}" --expiryDelay="${EXPIRYDELAY}" --checkDelay="${CHECKDELAY}"

# Run
echo "Run Codex Crawler"
exec "$@"
