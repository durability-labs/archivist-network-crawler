import std/net
import ./version

let doc =
  """
Codex Network Crawler. Generates network metrics.

Usage:
  codexcrawler [--logLevel=<l>] [--metricsAddress=<ip>] [--metricsPort=<p>] [--dataDir=<dir>] [--discoveryPort=<p>]

Options:
  --logLevel=<l>          Sets log level [default: TRACE]
  --metricsAddress=<ip>   Listen address of the metrics server [default: 0.0.0.0]
  --metricsPort=<p>       Listen HTTP port of the metrics server [default: 8008]
  --dataDir=<dir>         Directory for storing data [default: crawler_data]
  --discoveryPort=<p>     Port used for DHT [default: 8090]
"""

import strutils
import docopt

type CrawlerConfig* = ref object
  logLevel*: string
  metricsAddress*: IpAddress
  metricsPort*: Port
  dataDir*: string
  discPort*: Port

proc `$`*(config: CrawlerConfig): string =
  "CrawlerConfig:" & " logLevel=" & config.logLevel & " metricsAddress=" &
    $config.metricsAddress & " metricsPort=" & $config.metricsPort & " dataDir=" &
    config.dataDir & " discPort=" & $config.discPort

proc parseConfig*(): CrawlerConfig =
  let args = docopt(doc, version = crawlerFullVersion)

  proc get(name: string): string =
    $args[name]

  return CrawlerConfig(
    logLevel: get("--logLevel"),
    metricsAddress: parseIpAddress(get("--metricsAddress")),
    metricsPort: Port(parseInt(get("--metricsPort"))),
    dataDir: get("--dataDir"),
    discPort: Port(parseInt(get("--discoveryPort"))),
  )
