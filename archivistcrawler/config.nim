import std/net
import std/sequtils
import pkg/chronicles
import pkg/libp2p
import pkg/archivistdht
import ./utils/version

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
  --bootNodes=<n>                   Semi-colon-separated list of Archivist bootstrap SPRs [default: testnet_sprs]

  --dhtEnable=<e>                   Set to "1" to enable DHT crawler [default: 1]
  --stepDelay=<ms>                  Delay in milliseconds per node visit [default: 1000]
  --revisitDelay=<m>                Delay in minutes after which a node can be revisited [default: 60]
  --checkDelay=<m>                  Delay with which the 'revisitDelay' is checked for all known nodes [default: 10]
  --expiryDelay=<m>                 Delay in minutes after which unresponsive nodes are discarded [default: 1440] (24h)

  --marketplaceEnable=<e>           Set to "1" to enable marketplace metrics [default: 1]
  --ethProvider=<a>                 Address including http(s) or ws of the eth provider
  --marketplaceAddress=<a>          Eth address of Archivist contracts deployment
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

proc getDefaultTestnetBootNodes(): seq[string] =
  @[
    "spr:CiUIAhIhA5mg11LZgFQ4XzIRb1T5xw9muFW1ALNKTijyKhQmvKYXEgIDARpJCicAJQgCEiEDmaDXUtmAVDhfMhFvVPnHD2a4VbUAs0pOKPIqFCa8phcQl-XFxQYaCwoJBE4vqKqRAnU6GgsKCQROL6iqkQJ1OipHMEUCIQDfzVYbN6A_O4i29e_FtDDUo7GJS3bkXRQtoteYbPSFtgIgcc8Kgj2ggVJyK16EY9xi4bY2lpTTeNIRjvslXSRdN5w",
    "spr:CiUIAhIhAhmlZ1XaN44zPDuORyNJV8I79x2eSXt5-9AirVagKCAIEgIDARpJCicAJQgCEiECGaVnVdo3jjM8O45HI0lXwjv3HZ5Je3n70CKtVqAoIAgQ_OfFxQYaCwoJBAWhGBORAnVEGgsKCQQFoRgTkQJ1RCpHMEUCIQCgqSYPxyic9XmOcQYtJDKNprK_Uokz2UzjVZRnPYpOgQIgQ8m96ukov4XZG-j-XH53_vuoy3GkHuneUZ1Xe0luCxk",
    "spr:CiUIAhIhAnCcHA-aqMx--nwf8cJyZKJavc-PuYNKKROoW_5Q1JcREgIDARpJCicAJQgCEiECcJwcD5qozH76fB_xwnJkolq9z4-5g0opE6hb_lDUlxEQje7FxQYaCwoJBAXfFdCRAnVOGgsKCQQF3xXQkQJ1TipGMEQCIA22oUekTsDAtsIOyrgtkG702FJPn8Xd-ifEVTUSuu7fAiBv9YyAg9iKuYBhgZKsZBHYfX8l0sXvm80s6U__EGGY-g",
  ]


proc getDefaultDevnetBootNodes(): seq[string] =
  @[
    "spr:CiUIAhIhA5mg11LZgFQ4XzIRb1T5xw9muFW1ALNKTijyKhQmvKYXEgIDARpJCicAJQgCEiEDmaDXUtmAVDhfMhFvVPnHD2a4VbUAs0pOKPIqFCa8phcQl-XFxQYaCwoJBE4vqKqRAnU6GgsKCQROL6iqkQJ1OipHMEUCIQDfzVYbN6A_O4i29e_FtDDUo7GJS3bkXRQtoteYbPSFtgIgcc8Kgj2ggVJyK16EY9xi4bY2lpTTeNIRjvslXSRdN5w",
    "spr:CiUIAhIhAhmlZ1XaN44zPDuORyNJV8I79x2eSXt5-9AirVagKCAIEgIDARpJCicAJQgCEiECGaVnVdo3jjM8O45HI0lXwjv3HZ5Je3n70CKtVqAoIAgQ_OfFxQYaCwoJBAWhGBORAnVEGgsKCQQFoRgTkQJ1RCpHMEUCIQCgqSYPxyic9XmOcQYtJDKNprK_Uokz2UzjVZRnPYpOgQIgQ8m96ukov4XZG-j-XH53_vuoy3GkHuneUZ1Xe0luCxk",
    "spr:CiUIAhIhAnCcHA-aqMx--nwf8cJyZKJavc-PuYNKKROoW_5Q1JcREgIDARpJCicAJQgCEiECcJwcD5qozH76fB_xwnJkolq9z4-5g0opE6hb_lDUlxEQje7FxQYaCwoJBAXfFdCRAnVOGgsKCQQF3xXQkQJ1TipGMEQCIA22oUekTsDAtsIOyrgtkG702FJPn8Xd-ifEVTUSuu7fAiBv9YyAg9iKuYBhgZKsZBHYfX8l0sXvm80s6U__EGGY-g",
  ]

proc getBootNodeStrings(input: string): seq[string] =
  if input == "testnet_sprs":
    return getDefaultTestnetBootNodes()
  elif input == "devnet_sprs":
    return getDefaultDevnetBootNodes()
  return input.split(";")

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

proc getBootNodes(input: string): seq[SignedPeerRecord] =
  getBootNodeStrings(input).mapIt(stringToSpr(it))

proc getEnable(input: string): bool =
  input == "1"

proc parseConfig*(): Config =
  let args = docopt(doc, version = crawlerFullVersion)

  proc get(name: string): string =
    $args[name]

  return Config(
    logLevel: get("--logLevel"),
    publicIp: get("--publicIp"),
    metricsAddress: parseIpAddress(get("--metricsAddress")),
    metricsPort: Port(parseInt(get("--metricsPort"))),
    dataDir: get("--dataDir"),
    discPort: Port(parseInt(get("--discoveryPort"))),
    bootNodes: getBootNodes(get("--bootNodes")),
    dhtEnable: getEnable(get("--dhtEnable")),
    stepDelayMs: parseInt(get("--stepDelay")),
    revisitDelayMins: parseInt(get("--revisitDelay")),
    checkDelayMins: parseInt(get("--checkDelay")),
    expiryDelayMins: parseInt(get("--expiryDelay")),
    marketplaceEnable: getEnable(get("--marketplaceEnable")),
    ethProvider: get("--ethProvider"),
    marketplaceAddress: get("--marketplaceAddress"),
    requestCheckDelay: parseInt(get("--requestCheckDelay")),
  )
