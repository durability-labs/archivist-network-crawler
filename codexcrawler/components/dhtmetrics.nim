import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ../list
import ../state
import ../services/metrics
import ../component
import ../utils/asyncdataevent

logScope:
  topics = "dhtmetrics"

type DhtMetrics* = ref object of Component
  state: State
  ok: List
  nok: List
  sub: AsyncDataEventSubscription
  metrics: Metrics

proc handleCheckEvent(
    d: DhtMetrics, event: DhtNodeCheckEventData
): Future[?!void] {.async.} =
  if event.isOk:
    ?await d.ok.add(event.id)
    ?await d.nok.remove(event.id)
  else:
    ?await d.ok.remove(event.id)
    ?await d.nok.add(event.id)

  d.metrics.setOkNodes(d.ok.len)
  d.metrics.setNokNodes(d.nok.len)

  return success()

method start*(d: DhtMetrics): Future[?!void] {.async.} =
  info "Starting DhtMetrics..."
  ?await d.ok.load()
  ?await d.nok.load()

  proc onCheck(event: DhtNodeCheckEventData): Future[?!void] {.async.} =
    await d.handleCheckEvent(event)

  d.sub = d.state.events.dhtNodeCheck.subscribe(onCheck)
  return success()

method stop*(d: DhtMetrics): Future[?!void] {.async.} =
  await d.state.events.dhtNodeCheck.unsubscribe(d.sub)
  return success()

proc new*(
    T: type DhtMetrics, state: State, okList: List, nokList: List, metrics: Metrics
): DhtMetrics =
  DhtMetrics(state: state, ok: okList, nok: nokList, metrics: metrics)

proc createDhtMetrics*(state: State, metrics: Metrics): ?!DhtMetrics =
  without okList =? createList(state.config.dataDir, "dhtok"), err:
    return failure(err)
  without nokList =? createList(state.config.dataDir, "dhtnok"), err:
    return failure(err)

  success(DhtMetrics.new(state, okList, nokList, metrics))
