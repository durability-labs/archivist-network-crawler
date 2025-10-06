import std/envvars
import std/httpclient
import std/sequtils

import pkg/serde/json
import pkg/questionable
import pkg/questionable/results

# Endpoint types
type
  NetworkConfig* = object
    latest* {.serialize.}: string 
    archivist* {.serialize.}: seq[ArchivistVersionEntry]
    sprs* {.serialize.}: seq[ArchivistSprEntry]
    rpcs* {.serialize.}: seq[string]
    marketplace* {.serialize.}: seq[ArchivistMarketplaceEntry]
    team* {.serialize.}: ArchivistNetworkTeamObject 

  ArchivistVersionEntry* = object
    version* {.serialize.}: string 
    revision* {.serialize.}: string 
    contracts* {.serialize.}: string 

  ArchivistSprEntry* = object
    supportedVersions* {.serialize.}: seq[string]
    records* {.serialize.}: seq[string]

  ArchivistMarketplaceEntry* = object
    supportedVersions* {.serialize.}: seq[string]
    contractAddress* {.serialize.}: string 
    abi* {.serialize.}: string 

  ArchivistNetworkTeamObject* = object
    nodes* {.serialize.}: seq[ArchivistNetworkTeamNodesEntry]
    utils* {.serialize.}: ArchivistNetworkTeamUtilsObject 

  ArchivistNetworkTeamNodesEntry* = object
    category* {.serialize.}: string 
    versions* {.serialize.}: seq[ArchivistNetworkTeamNodesVersionsEntry]

  ArchivistNetworkTeamNodesVersionsEntry* = object
    version* {.serialize.}: string 
    instances* {.serialize.}: seq[ArchivistNetworkTeamNodesVersionsInstancesEntry]

  ArchivistNetworkTeamNodesVersionsInstancesEntry* = object
    name* {.serialize.}: string 
    podName* {.serialize.}: string 
    ethAddress* {.serialize.}: string 

  ArchivistNetworkTeamUtilsObject* = object
    crawlerRpc* {.serialize.}: string 
    botRpc* {.serialize.}: string 
    elasticSearch* {.serialize.}: string 

# Application types
type
  ArchivistNetwork* = object
    version* {.serialize.}: ArchivistVersionEntry 
    spr* {.serialize.}: ArchivistSprEntry 
    rpcs* {.serialize.}: seq[string] 
    marketplace* {.serialize.}: ArchivistMarketplaceEntry 
    team* {.serialize.}: TeamObject 

  TeamObject* = object
    nodes* {.serialize.}: seq[TeamNodesCategory] 
    utils* {.serialize.}: ArchivistNetworkTeamUtilsObject 

  TeamNodesCategory* = object
    category* {.serialize.}: string 
    instances* {.serialize.}: seq[ArchivistNetworkTeamNodesVersionsInstancesEntry] 

# Connector
const EnvVar_Network = "ARCHIVIST_NETWORK";
const EnvVar_Version = "ARCHIVIST_VERSION";
const EnvVar_ConfigUrl = "ARCHIVIST_CONFIG_URL";
const EnvVar_ConfigFile = "ARCHIVIST_CONFIG_FILE";

proc getEnvOrDefault(key: string, default: string): string =
  return getEnv(key, default)

proc fetchModelFromFile(file: string): string =
  return readFile(file)

proc getFetchUrl(): string =
  let overrideUrl = getEnvOrDefault(EnvVar_ConfigUrl, "")
  if overrideUrl.len > 0:
    return overrideUrl

  let network = getEnvOrDefault(EnvVar_Network, "testnet")
  return "http://config.archivist.storage/" & network & ".json"

proc fetchModelFromUrl(): string =
  let
    url = getFetchUrl()
    client = newHttpClient()
  try:
    return client.getContent(url)
  finally:
    client.close()

proc fetchModelJson(): string =
  let overrideFile = getEnvOrDefault(EnvVar_ConfigFile, "")
  if overrideFile.len > 0:
    return fetchModelFromFile(overrideFile)
  return fetchModelFromUrl()

proc fetchModel(): NetworkConfig =
  let str = fetchModelJson()
  return tryGet(NetworkConfig.fromJson(str))

proc getVersion(fullModel: NetworkConfig): string =
  let selected = getEnvOrDefault(EnvVar_Version, "latest")
  if selected == "latest":
    return fullModel.latest
  return selected

proc mapToVersion(nodes: seq[ArchivistNetworkTeamNodesEntry], selected: string): seq[TeamNodesCategory] =
  return nodes.mapIt(
    TeamNodesCategory(
      category: it.category,
      instances: it.versions.filterIt(it.version == selected)[0].instances
    )
  )

proc mapToVersion(team: ArchivistNetworkTeamObject, selected: string): TeamObject =
  return TeamObject(
    nodes: mapToVersion(team.nodes, selected),
    utils: team.utils
  )

proc mapToVersion(fullModel: NetworkConfig): ArchivistNetwork =
  let selected = getVersion(fullModel)
  return ArchivistNetwork(
    version: fullModel.archivist.filterIt(it.version == selected)[0],
    spr: fullModel.sprs.filterIt(it.supportedVersions.contains(selected))[0],
    rpcs: fullModel.rpcs,
    marketplace: fullModel.marketplace.filterIt(it.supportedVersions.contains(selected))[0],
    team: mapToVersion(fullModel.team, selected)
  )

proc getNetworkConfig*(): ArchivistNetwork =
  let fullModel = fetchModel()
  return mapToVersion(fullModel)
