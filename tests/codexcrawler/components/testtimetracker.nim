import pkg/chronos
import pkg/questionable/results
import pkg/asynctest/chronos/unittest

import ../../../codexcrawler/components/timetracker
import ../../../codexcrawler/components/nodestore
import ../../../codexcrawler/utils/asyncdataevent
import ../../../codexcrawler/types
import ../../../codexcrawler/state
import ../mockstate
import ../mocknodestore
import ../helpers

suite "TimeTracker":
  var
    nid: Nid
    state: MockState
    store: MockNodeStore
    time: TimeTracker
    expiredNodesReceived: seq[Nid]
    sub: AsyncDataEventSubscription

  setup:
    nid = genNid()
    state = createMockState()
    store = createMockNodeStore()

    # Subscribe to nodesExpired event
    expiredNodesReceived = newSeq[Nid]()
    proc onExpired(nids: seq[Nid]): Future[?!void] {.async.} =
      expiredNodesReceived = nids
      return success()

    sub = state.events.nodesExpired.subscribe(onExpired)

    state.config.revisitDelayMins = 22

    time = TimeTracker.new(state, store)

    (await time.start()).tryGet()

  teardown:
    (await time.stop()).tryGet()
    await state.events.nodesExpired.unsubscribe(sub)
    state.checkAllUnsubscribed()

  proc createNodeInStore(lastVisit: uint64): Nid =
    let entry = NodeEntry(id: genNid(), lastVisit: lastVisit)
    store.nodesToIterate.add(entry)
    return entry.id

  test "onStep fires nodesExpired event for expired nodes":
    let
      expiredTimestamp =
        (Moment.now().epochSeconds - ((1 + state.config.revisitDelayMins) * 60)).uint64
      expiredNodeId = createNodeInStore(expiredTimestamp)

    (await state.stepper()).tryGet()

    check:
      expiredNodeId in expiredNodesReceived

  test "onStep does not fire nodesExpired event for nodes that are recent":
    let
      recentTimestamp =
        (Moment.now().epochSeconds - ((state.config.revisitDelayMins - 1) * 60)).uint64
      recentNodeId = createNodeInStore(recentTimestamp)

    (await state.stepper()).tryGet()

    check:
      recentNodeId notin expiredNodesReceived
