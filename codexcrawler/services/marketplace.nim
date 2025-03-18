import pkg/ethers
import pkg/questionable
import ./marketplace/market
import ./marketplace/marketplace
import ../config
import ../component
import ../state

logScope:
  topics = "marketplace"

type MarketplaceService* = ref object of Component
  state: State
  market: ?OnChainMarket

method getRecentSlotFillEvents*(
    m: MarketplaceService
): Future[?!seq[SlotFilled]] {.async: (raises: []), base.} =
  # There is (aprox.) 1 block every 10 seconds.
  # 10 seconds * 6 * 60 = 3600 = 1 hour.
  let blocksAgo = 6 * 60

  if market =? m.market:
    try:
      return success(await market.queryPastSlotFilledEvents(blocksAgo))
    except CatchableError as err:
      return failure(err.msg)
  return failure("MarketplaceService is not started")

method start*(m: MarketplaceService): Future[?!void] {.async.} =
  let provider = JsonRpcProvider.new(m.state.config.ethProvider)
  without marketplaceAddress =? Address.init(m.state.config.marketplaceAddress):
    return failure("Invalid MarketplaceAddress provided")

  let marketplace = Marketplace.new(marketplaceAddress, provider)
  m.market = some(OnChainMarket.new(marketplace))

  return success()

method stop*(m: MarketplaceService): Future[?!void] {.async.} =
  return success()

proc new(T: type MarketplaceService, state: State): MarketplaceService =
  return MarketplaceService(state: state, market: none(OnChainMarket))

proc createMarketplace*(state: State): MarketplaceService =
  return MarketplaceService.new(state)
