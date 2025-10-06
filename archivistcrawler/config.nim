import std/net
import std/sequtils
import pkg/chronicles
import pkg/libp2p
import pkg/archivistdht
import ./utils/version
import ./networkConfig

let doc =
  """
Archivist Network Crawler. Generates network metrics.

Usage:
  archivistcrawler [--logLevel=<l>] [--publicIp=<a>] [--metricsAddress=<ip>] [--metricsPort=<p>] [--dataDir=<dir>] [--discoveryPort=<p>] [--bootNodes=<n>] [--dhtEnable=<e>] [--stepDelay=<ms>] [--revisitDelay=<m>] [--checkDelay=<m>]  [--expiryDelay=<m>] [--marketplaceEnable=<e>] [--ethProvider=<a>] [--marketplaceAddress=<a>] [--requestCheckDelay=<m>]

Options:
  --logLevel=<l>                    Sets log level [default: INFO]
  --publicIp=<a>                    Public IP address where this instance is reachable.
  --metricsAddress=<ip>             Listen address of the metrics server [default: 0.0.0.0]
  --metricsPort=<p>                 Listen HTTP port of the metrics server [default: 8008]
  --dataDir=<dir>                   Directory for storing data [default: crawler_data]
  --discoveryPort=<p>               Port used for DHT [default: 8090]
  --bootNodes=<n>                   Override for bootstrap SPRs. Semi-colon-separated list. [default: network_default]

  --dhtEnable=<e>                   Set to "1" to enable DHT crawler [default: 1]
  --stepDelay=<ms>                  Delay in milliseconds per node visit [default: 1000]
  --revisitDelay=<m>                Delay in minutes after which a node can be revisited [default: 60]
  --checkDelay=<m>                  Delay with which the 'revisitDelay' is checked for all known nodes [default: 10]
  --expiryDelay=<m>                 Delay in minutes after which unresponsive nodes are discarded [default: 1440] (24h)

  --marketplaceEnable=<e>           Set to "1" to enable marketplace metrics [default: 1]
  --ethProvider=<a>                 Override address including http(s) or ws of the eth provider [default: network_default]
  --marketplaceAddress=<a>          Override Eth address of Archivist contracts deployment [default: network_default]
  --requestCheckDelay=<m>           Delay in minutes after which storage contract status is (re)checked [default: 10]
"""

import strutils
import docopt

type Config* = ref object
  logLevel*: string
  publicIp*: string
  metricsAddress*: IpAddress
  metricsPort*: Port
  dataDir*: string
  discPort*: Port
  bootNodes*: seq[SignedPeerRecord]

  dhtEnable*: bool
  stepDelayMs*: int
  revisitDelayMins*: int
  checkDelayMins*: int
  expiryDelayMins*: int

  marketplaceEnable*: bool
  ethProvider*: string
  marketplaceAddress*: string
  requestCheckDelay*: int

const networkDefault = "network_default"

proc `$`*(config: Config): string =
  "Crawler:" & " logLevel=" & config.logLevel & " publicIp=" & config.publicIp &
    " metricsAddress=" & $config.metricsAddress & " metricsPort=" & $config.metricsPort &
    " dataDir=" & config.dataDir & " discPort=" & $config.discPort & " dhtEnable=" &
    $config.dhtEnable & " bootNodes=" & config.bootNodes.mapIt($it).join(";") &
    " stepDelay=" & $config.stepDelayMs & " revisitDelayMins=" & $config.revisitDelayMins &
    " expiryDelayMins=" & $config.expiryDelayMins & " checkDelayMins=" &
    $config.checkDelayMins & " marketplaceEnable=" & $config.marketplaceEnable &
    " ethProvider=" & config.ethProvider & " marketplaceAddress=" &
    config.marketplaceAddress & " requestCheckDelay=" & $config.requestCheckDelay

proc stringToSpr(uri: string): SignedPeerRecord =
  var res: SignedPeerRecord
  try:
    if not res.fromURI(uri):
      warn "Invalid SignedPeerRecord uri", uri = uri
      quit QuitFailure
  except LPError as exc:
    warn "Invalid SignedPeerRecord uri", uri = uri, error = exc.msg
    quit QuitFailure
  except CatchableError as exc:
    warn "Invalid SignedPeerRecord uri", uri = uri, error = exc.msg
    quit QuitFailure
  res

proc getBootNodes(
    networkConfig: ArchivistNetwork, input: string
): seq[SignedPeerRecord] =
  if input == networkDefault:
    return networkConfig.spr.records.mapIt(stringToSpr(it))
  return input.split(";").mapIt(stringToSpr(it))

proc getEthProvider(networkConfig: ArchivistNetwork, input: string): string =
  if input == networkDefault:
    return networkConfig.rpcs[0]
  return input

proc getMarketplaceAddress(networkConfig: ArchivistNetwork, input: string): string =
  if input == networkDefault:
    return networkConfig.marketplace.contractAddress
  return input

proc getEnable(input: string): bool =
  input == "1"

proc parseConfig*(): Config =
  let
    args = docopt(doc, version = crawlerFullVersion)
    networkConfig = getNetworkConfig()

  proc get(name: string): string =
    $args[name]

  return Config(
    logLevel: get("--logLevel"),
    publicIp: get("--publicIp"),
    metricsAddress: parseIpAddress(get("--metricsAddress")),
    metricsPort: Port(parseInt(get("--metricsPort"))),
    dataDir: get("--dataDir"),
    discPort: Port(parseInt(get("--discoveryPort"))),
    bootNodes: getBootNodes(networkConfig, get("--bootNodes")),
    dhtEnable: getEnable(get("--dhtEnable")),
    stepDelayMs: parseInt(get("--stepDelay")),
    revisitDelayMins: parseInt(get("--revisitDelay")),
    checkDelayMins: parseInt(get("--checkDelay")),
    expiryDelayMins: parseInt(get("--expiryDelay")),
    marketplaceEnable: getEnable(get("--marketplaceEnable")),
    ethProvider: getEthProvider(networkConfig, get("--ethProvider")),
    marketplaceAddress:
      getMarketplaceAddress(networkConfig, get("--marketplaceAddress")),
    requestCheckDelay: parseInt(get("--requestCheckDelay")),
  )
