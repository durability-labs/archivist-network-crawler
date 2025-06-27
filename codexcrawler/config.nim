import std/net
import std/sequtils
import pkg/chronicles
import pkg/libp2p
import pkg/codexdht
import ./utils/version

let doc =
  """
Codex Network Crawler. Generates network metrics.

Usage:
  codexcrawler [--logLevel=<l>] [--publicIp=<a>] [--metricsAddress=<ip>] [--metricsPort=<p>] [--dataDir=<dir>] [--discoveryPort=<p>] [--bootNodes=<n>] [--dhtEnable=<e>] [--stepDelay=<ms>] [--revisitDelay=<m>] [--checkDelay=<m>]  [--expiryDelay=<m>] [--marketplaceEnable=<e>] [--ethProvider=<a>] [--marketplaceAddress=<a>] [--requestCheckDelay=<m>]

Options:
  --logLevel=<l>                    Sets log level [default: INFO]
  --publicIp=<a>                    Public IP address where this instance is reachable.
  --metricsAddress=<ip>             Listen address of the metrics server [default: 0.0.0.0]
  --metricsPort=<p>                 Listen HTTP port of the metrics server [default: 8008]
  --dataDir=<dir>                   Directory for storing data [default: crawler_data]
  --discoveryPort=<p>               Port used for DHT [default: 8090]
  --bootNodes=<n>                   Semi-colon-separated list of Codex bootstrap SPRs [default: testnet_sprs]

  --dhtEnable=<e>                   Set to "1" to enable DHT crawler [default: 1]
  --stepDelay=<ms>                  Delay in milliseconds per node visit [default: 1000]
  --revisitDelay=<m>                Delay in minutes after which a node can be revisited [default: 60]
  --checkDelay=<m>                  Delay with which the 'revisitDelay' is checked for all known nodes [default: 10]
  --expiryDelay=<m>                 Delay in minutes after which unresponsive nodes are discarded [default: 1440] (24h)

  --marketplaceEnable=<e>           Set to "1" to enable marketplace metrics [default: 1]
  --ethProvider=<a>                 Address including http(s) or ws of the eth provider
  --marketplaceAddress=<a>          Eth address of Codex contracts deployment
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
    "spr:CiUIAhIhAiJvIcA_ZwPZ9ugVKDbmqwhJZaig5zKyLiuaicRcCGqLEgIDARo8CicAJQgCEiECIm8hwD9nA9n26BUoNuarCEllqKDnMrIuK5qJxFwIaosQ3d6esAYaCwoJBJ_f8zKRAnU6KkYwRAIgM0MvWNJL296kJ9gWvfatfmVvT-A7O2s8Mxp8l9c8EW0CIC-h-H-jBVSgFjg3Eny2u33qF7BDnWFzo7fGfZ7_qc9P",
    "spr:CiUIAhIhAyUvcPkKoGE7-gh84RmKIPHJPdsX5Ugm_IHVJgF-Mmu_EgIDARo8CicAJQgCEiEDJS9w-QqgYTv6CHzhGYog8ck92xflSCb8gdUmAX4ya78QoemesAYaCwoJBES39Q2RAnVOKkYwRAIgLi3rouyaZFS_Uilx8k99ySdQCP1tsmLR21tDb9p8LcgCIG30o5YnEooQ1n6tgm9fCT7s53k6XlxyeSkD_uIO9mb3",
    "spr:CiUIAhIhAlNJ7ary8eOK5GcwQ6q4U8brR7iWjwhMwzHb8BzzmCEDEgIDARpJCicAJQgCEiECU0ntqvLx44rkZzBDqrhTxutHuJaPCEzDMdvwHPOYIQMQsZ67vgYaCwoJBK6Kf1-RAnVEGgsKCQSuin9fkQJ1RCpGMEQCIDxd6lXDvj1PcHgQYnNpHGfgCO5a7fejg3WhSjh2wTimAiB7YHsL1WZYU_zkHcNDWhRgMbkb3C5yRuvUhjBjGOYJYQ",
    "spr:CiUIAhIhA7E4DEMer8nUOIUSaNPA4z6x0n9Xaknd28Cfw9S2-cCeEgIDARo8CicAJQgCEiEDsTgMQx6vydQ4hRJo08DjPrHSf1dqSd3bwJ_D1Lb5wJ4Qt_CesAYaCwoJBEDhWZORAnVYKkYwRAIgFNzhnftocLlVHJl1onuhbSUM7MysXPV6dawHAA0DZNsCIDRVu9gnPTH5UkcRXLtt7MLHCo4-DL-RCMyTcMxYBXL0",
    "spr:CiUIAhIhAzZn3JmJab46BNjadVnLNQKbhnN3eYxwqpteKYY32SbOEgIDARo8CicAJQgCEiEDNmfcmYlpvjoE2Np1Wcs1ApuGc3d5jHCqm14phjfZJs4QrvWesAYaCwoJBKpA-TaRAnViKkcwRQIhANuMmZDD2c25xzTbKSirEpkZYoxbq-FU_lpI0K0e4mIVAiBfQX4yR47h1LCnHznXgDs6xx5DLO5q3lUcicqUeaqGeg",
    "spr:CiUIAhIhAuN-P1D0HrJdwBmrRlZZzg6dqllRNNcQyMDUMuRtg3paEgIDARpJCicAJQgCEiEC434_UPQesl3AGatGVlnODp2qWVE01xDIwNQy5G2DeloQm_L2vQYaCwoJBI_0zSiRAnVsGgsKCQSP9M0okQJ1bCpHMEUCIQDgEVjUp1RJGb59eRPs7RPYMSGAI_fo1yv70iBtnTqefQIgVoXszc87EGFVO3aaqorEYZ21OGRko5ho_Pybdyqa6AI",
    "spr:CiUIAhIhAsi_hgxFppWjHiKRwnYPX_qkB28dLtwK9c7apnlBanFuEgIDARpJCicAJQgCEiECyL-GDEWmlaMeIpHCdg9f-qQHbx0u3Ar1ztqmeUFqcW4Q2O32vQYaCwoJBNEmoCiRAnV2GgsKCQTRJqAokQJ1dipHMEUCIQDpC1isFfdRqNmZBfz9IGoEq7etlypB6N1-9Z5zhvmRMAIgIOsleOPr5Ra_Nk7BXmXGhe-YlLosH9jo83JtfWCy3-o",
    "spr:CiUIAhIhA2AEPzVj1Z_pshWAwvTp0xvRZTigIkYphXGZdiYGmYRwEgIDARo8CicAJQgCEiEDYAQ_NWPVn-myFYDC9OnTG9FlOKAiRimFcZl2JgaZhHAQvKCXugYaCwoJBES3CuORAnd-KkYwRAIgNwrc7n8A107pYUoWfJxL8X0f-flfUKeA6bFrjVKzEo0CID_0q-KO5ZAGf65VsK-d9rV3S0PbFg7Hj3Cv4aVX2Lnn",
    "spr:CiUIAhIhAuhggJhkjeRoR7MHjZ_L_naZKnjF541X0GXTI7LEwXi_EgIDARo8CicAJQgCEiEC6GCAmGSN5GhHsweNn8v-dpkqeMXnjVfQZdMjssTBeL8Qop2quwYaCwoJBJK-4V-RAncuKkYwRAIgaXWoxvKkzrjUZ5K_ayQHKNlYhUEzBXhGviujxfJiGXkCICbsYFivi6Ny1FT6tbofVBRj7lnaR3K9_3j5pUT4862k",
    "spr:CiUIAhIhA-pnA5sLGDVbqEXsRxDUjQEpiSAximHNbyqr2DwLmTq8EgIDARo8CicAJQgCEiED6mcDmwsYNVuoRexHENSNASmJIDGKYc1vKqvYPAuZOrwQyrekvAYaCwoJBIDHOw-RAnc4KkcwRQIhAJtKNeTykcE5bkKwe-vhSmqyBwc2AnexqFX1tAQGLQJ4AiBJOPseqvI3PyEM8l3hY3zvelZU9lT03O7MA_8cUfF4Uw",
  ]

proc getDefaultDevnetBootNodes(): seq[string] =
  @[
    "spr:CiUIAhIhA-VlcoiRm02KyIzrcTP-ljFpzTljfBRRKTIvhMIwqBqWEgIDARpJCicAJQgCEiED5WVyiJGbTYrIjOtxM_6WMWnNOWN8FFEpMi-EwjCoGpYQs8n8wQYaCwoJBHTKubmRAnU6GgsKCQR0yrm5kQJ1OipHMEUCIQDwUNsfReB4ty7JFS5WVQ6n1fcko89qVAOfQEHixa03rgIgan2-uFNDT-r4s9TOkLe9YBkCbsRWYCHGGVJ25rLj0QE",
    "spr:CiUIAhIhApIj9p6zJDRbw2NoCo-tj98Y760YbppRiEpGIE1yGaMzEgIDARpJCicAJQgCEiECkiP2nrMkNFvDY2gKj62P3xjvrRhumlGISkYgTXIZozMQvcz8wQYaCwoJBAWhF3WRAnVEGgsKCQQFoRd1kQJ1RCpGMEQCIFZB84O_nzPNuViqEGRL1vJTjHBJ-i5ZDgFL5XZxm4HAAiB8rbLHkUdFfWdiOmlencYVn0noSMRHzn4lJYoShuVzlw",
    "spr:CiUIAhIhApqRgeWRPSXocTS9RFkQmwTZRG-Cdt7UR2N7POoz606ZEgIDARpJCicAJQgCEiECmpGB5ZE9JehxNL1EWRCbBNlEb4J23tRHY3s86jPrTpkQj8_8wQYaCwoJBAXfEfiRAnVOGgsKCQQF3xH4kQJ1TipGMEQCIGWJMsF57N1iIEQgTH7IrVOgEgv0J2P2v3jvQr5Cjy-RAiAy4aiZ8QtyDvCfl_K_w6SyZ9csFGkRNTpirq_M_QNgKw",
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
