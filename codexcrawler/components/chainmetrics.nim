import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ../state
import ../services/metrics
import ../services/marketplace
import ../components/requeststore
import ../component
import ../types

logScope:
  topics = "chainmetrics"

type
  ChainMetrics* = ref object of Component
    state: State
    metrics: Metrics
    store: RequestStore
    marketplace: MarketplaceService

  Update = ref object
    numRequests: int
    numSlots: int
    totalSize: int64

proc collectUpdate(c: ChainMetrics): Future[?!Update] {.async: (raises: []).} =
  var update = Update(numRequests: 0, numSlots: 0, totalSize: 0)

  proc onRequest(entry: RequestEntry): Future[?!void] {.async: (raises: []).} =
    let response = await c.marketplace.getRequestInfo(entry.id)
    if info =? response:
      inc update.numRequests
      update.numSlots += info.slots.int
      update.totalSize += (info.slots * info.slotSize).int64
    else:
      ?await c.store.remove(entry.id)
    return success()

  ?await c.store.iterateAll(onRequest)
  return success(update)

proc updateMetrics(c: ChainMetrics, update: Update) =
  c.metrics.setRequests(update.numRequests)
  c.metrics.setRequestSlots(update.numSlots)
  c.metrics.setTotalSize(update.totalSize)

proc step(c: ChainMetrics): Future[?!void] {.async: (raises: []).} =
  without update =? (await c.collectUpdate()), err:
    return failure(err)

  c.updateMetrics(update)
  return success()

method start*(c: ChainMetrics): Future[?!void] {.async.} =
  info "starting..."

  proc onStep(): Future[?!void] {.async: (raises: []), gcsafe.} =
    return await c.step()

  if c.state.config.marketplaceEnable:
    await c.state.whileRunning(onStep, 10.minutes)

  return success()

method stop*(c: ChainMetrics): Future[?!void] {.async.} =
  return success()

proc new*(
    T: type ChainMetrics,
    state: State,
    metrics: Metrics,
    store: RequestStore,
    marketplace: MarketplaceService,
): ChainMetrics =
  ChainMetrics(state: state, metrics: metrics, store: store, marketplace: marketplace)
