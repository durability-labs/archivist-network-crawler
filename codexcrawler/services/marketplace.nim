import pkg/ethers
import pkg/questionable

import ./marketplace/market
import ./marketplace/marketplace
import ../config
import ../component
import ../state

logScope:
  topics = "marketplace"

type
  MarketplaceService* = ref object of Component
    state: State
    market: ?OnChainMarket

method getZkeyhash*(m: MarketplaceService): Future[?!string] {.async: (raises: []), base.} =
  try:
    if market =? m.market:
      without zkeyhash =? await market.getZkeyHash():
        return failure("Failed to get zkeyHash")
      return success(zkeyhash)
    return failure("MarketplaceService is not started")
  except CatchableError as err:
    return failure("Error while getting zkeyHash: " & err.msg)

method start*(m: MarketplaceService): Future[?!void] {.async.} =
  let provider = JsonRpcProvider.new(m.state.config.ethProvider)
  without marketplaceAddress =? Address.init(m.state.config.marketplaceAddress):
    return failure("Invalid MarketplaceAddress provided")

  let marketplace = Marketplace.new(marketplaceAddress, provider)
  m.market = some(OnChainMarket.new(marketplace))

  return success()

method stop*(m: MarketplaceService): Future[?!void] {.async.} =
  return success()

proc new(
    T: type MarketplaceService,
    state: State
): MarketplaceService =
  return MarketplaceService(
    state: state,
    market: none(OnChainMarket)
  )

proc createMarketplace*(state: State): MarketplaceService =
  return MarketplaceService.new(
    state
  )
