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
REVISITDELAY=${CRAWLER_REVISITDELAY:-1440}

# Update CLI arguments
set -- "$@" --logLevel="${LOGLEVEL}" --publicIp="${PUBLICIP}" --metricsAddress="${METRICSADDRESS}" --metricsPort="${METRICSPORT}" --dataDir="${DATADIR}" --discoveryPort="${DISCPORT}" --bootNodes="${BOOTNODES}" --stepDelay="${STEPDELAY}" --revisitDelay="${REVISITDELAY}"

# Run
echo "Run Codex Crawler"
exec "$@"
