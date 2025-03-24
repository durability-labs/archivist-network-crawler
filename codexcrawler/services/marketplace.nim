import pkg/ethers
import pkg/questionable
import pkg/upraises
import ./marketplace/market
import ./marketplace/marketplace
import ../config
import ../component
import ../state
import ../types
import ./clock

logScope:
  topics = "marketplace"

type
  MarketplaceService* = ref object of Component
    state: State
    market: ?OnChainMarket
    clock: Clock

  OnNewRequest* = proc(id: Rid): Future[?!void] {.async: (raises: []), gcsafe.}
  RequestInfo* = ref object
    pending*: bool
    slots*: uint64
    slotSize*: uint64

proc notStarted() =
  raiseAssert("MarketplaceService was called before it was started.")

proc fetchRequestInfo(
    market: OnChainMarket, rid: Rid
): Future[?RequestInfo] {.async: (raises: []).} =
  try:
    let request = await market.getRequest(rid)
    if r =? request:
      return
        some(RequestInfo(pending: false, slots: r.ask.slots, slotSize: r.ask.slotSize))
  except CatchableError as exc:
    trace "Failed to get request info", err = exc.msg
  return none(RequestInfo)

method subscribeToNewRequests*(
    m: MarketplaceService, onNewRequest: OnNewRequest
): Future[?!void] {.async: (raises: []), base.} =
  proc resultWrapper(rid: Rid): Future[void] {.async.} =
    let response = await onNewRequest(rid)
    if error =? response.errorOption:
      raiseAssert("Error result in handling of onNewRequest callback: " & error.msg)

  proc onRequest(
      id: RequestId, ask: StorageAsk, expiry: uint64
  ) {.gcsafe, upraises: [].} =
    asyncSpawn resultWrapper(Rid(id))

  if market =? m.market:
    try:
      discard await market.subscribeRequests(onRequest)
      return success()
    except CatchableError as exc:
      return failure(exc.msg)
  else:
    notStarted()

method iteratePastNewRequestEvents*(
    m: MarketplaceService, onNewRequest: OnNewRequest
): Future[?!void] {.async: (raises: []), base.} =
  let
    oneDay = 60 * 60 * 24
    timespan = oneDay * 30
    startTime = m.clock.now() - timespan.uint64

  if market =? m.market:
    try:
      let requests = await market.queryPastStorageRequestedEvents(startTime.int64)
      for request in requests:
        if error =? (await onNewRequest(Rid(request.requestId))).errorOption:
          return failure(error.msg)
      return success()
    except CatchableError as exc:
      return failure(exc.msg)
  else:
    notStarted()

method getRequestInfo*(
    m: MarketplaceService, rid: Rid
): Future[?RequestInfo] {.async: (raises: []), base.} =
  # If the request id exists and is running, fetch the request object and return the info object.
  # otherwise, return none.
  if market =? m.market:
    try:
      let state = await market.requestState(rid)
      if s =? state:
        if s == RequestState.New:
          return some(RequestInfo(pending: true))
        if s == RequestState.Started:
          return await market.fetchRequestInfo(rid)
    except CatchableError as exc:
      trace "Failed to get request state", err = exc.msg
    return none(RequestInfo)
  else:
    notStarted()

method awake*(m: MarketplaceService): Future[?!void] {.async.} =
  let provider = JsonRpcProvider.new(m.state.config.ethProvider)
  without marketplaceAddress =? Address.init(m.state.config.marketplaceAddress):
    return failure("Invalid MarketplaceAddress provided")

  let marketplace = Marketplace.new(marketplaceAddress, provider)
  m.market = some(OnChainMarket.new(marketplace))
  return success()

proc new(T: type MarketplaceService, state: State, clock: Clock): MarketplaceService =
  return MarketplaceService(state: state, market: none(OnChainMarket), clock: clock)

proc createMarketplace*(state: State, clock: Clock): MarketplaceService =
  return MarketplaceService.new(state, clock)
