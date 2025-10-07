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
    sprs* {.serialize.}: seq[ArchivistSprEntry]
    marketplace* {.serialize.}: seq[ArchivistMarketplaceEntry]
    team* {.serialize.}: ArchivistNetworkTeamObject

  ArchivistSprEntry* = object
    supportedVersions* {.serialize.}: seq[string]
    records* {.serialize.}: seq[string]

  ArchivistMarketplaceEntry* = object
    supportedVersions* {.serialize.}: seq[string]
    contractAddress* {.serialize.}: string

  ArchivistNetworkTeamObject* = object
    utils* {.serialize.}: ArchivistNetworkTeamUtilsObject

  ArchivistNetworkTeamUtilsObject* = object
    crawlerRpc* {.serialize.}: string
    botRpc* {.serialize.}: string
    elasticSearch* {.serialize.}: string

# Application types
type
  ArchivistNetwork* = object
    spr*: ArchivistSprEntry
    marketplace*: ArchivistMarketplaceEntry
    team*: TeamObject

  TeamObject* = object
    utils*: ArchivistNetworkTeamUtilsObject

# Connector
const EnvVarNetwork = "ARCHIVIST_NETWORK"
const EnvVarVersion = "ARCHIVIST_VERSION"
const EnvVarConfigUrl = "ARCHIVIST_CONFIG_URL"
const EnvVarConfigFile = "ARCHIVIST_CONFIG_FILE"

proc getEnvOrDefault(key: string, default: string): string =
  return getEnv(key, default)

proc fetchModelFromFile(file: string): string =
  return readFile(file)

proc getFetchUrl(): string =
  let overrideUrl = getEnvOrDefault(EnvVarConfigUrl, "")
  if overrideUrl.len > 0:
    return overrideUrl

  let network = getEnvOrDefault(EnvVarNetwork, "testnet")
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
  let overrideFile = getEnvOrDefault(EnvVarConfigFile, "")
  if overrideFile.len > 0:
    return fetchModelFromFile(overrideFile)
  return fetchModelFromUrl()

proc fetchModel(): NetworkConfig =
  let str = fetchModelJson()
  return tryGet(NetworkConfig.fromJson(str))

proc getVersion(fullModel: NetworkConfig): string =
  let selected = getEnvOrDefault(EnvVarVersion, "latest")
  if selected == "latest":
    return fullModel.latest
  return selected

proc mapToVersion(fullModel: NetworkConfig): ArchivistNetwork =
  let selected = getVersion(fullModel)
  return ArchivistNetwork(
    spr: fullModel.sprs.filterIt(it.supportedVersions.contains(selected))[0],
    marketplace:
      fullModel.marketplace.filterIt(it.supportedVersions.contains(selected))[0],
    team: TeamObject(utils: fullModel.team.utils),
  )

proc getNetworkConfig*(): ArchivistNetwork =
  let fullModel = fetchModel()
  return mapToVersion(fullModel)
