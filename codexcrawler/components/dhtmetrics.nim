import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ./dht
import ../list
import ../state
import ../component
import ../types
import ../utils/asyncdataevent
import ../metrics

logScope:
  topics = "dhtmetrics"

type DhtMetrics* = ref object of Component
  state: State
  ok: List
  nok: List

method start*(d: DhtMetrics): Future[?!void] {.async.} =
  info "Starting DhtMetrics..."
  return success()

method stop*(d: DhtMetrics): Future[?!void] {.async.} =
  return success()

proc new*(
    T: type DhtMetrics,
    state: State,
    okList: List,
    nokList: List
): DhtMetrics =
  DhtMetrics(
    state: state,
    ok: okList,
    nok: nokList
  )

proc createDhtMetrics*(state: State): ?!DhtMetrics =
  without okList =? createList(state.config.dataDir, "dhtok"), err:
    return failure(err)
  without nokList =? createList(state.config.dataDir, "dhtnok"), err:
    return failure(err)

  success(DhtMetrics.new(
    state,
    okList,
    nokList
  ))
