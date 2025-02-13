import pkg/chronos
import pkg/questionable/results
import pkg/asynctest/chronos/unittest

import ../../../codexcrawler/components/timetracker
import ../../../codexcrawler/components/nodestore
import ../../../codexcrawler/utils/asyncdataevent
import ../../../codexcrawler/types
import ../../../codexcrawler/state
import ../mocks/mockstate
import ../mocks/mocknodestore
import ../mocks/mockdht
import ../mocks/mockclock
import ../helpers

suite "TimeTracker":
  let now = 123456789.uint64

  var
    nid: Nid
    state: MockState
    store: MockNodeStore
    clock: MockClock
    dht: MockDht
    time: TimeTracker
    expiredNodesReceived: seq[Nid]
    sub: AsyncDataEventSubscription

  setup:
    nid = genNid()
    state = createMockState()
    store = createMockNodeStore()
    clock = createMockClock()
    dht = createMockDht()

    clock.setNow = now

    # Subscribe to nodesExpired event
    expiredNodesReceived = newSeq[Nid]()
    proc onExpired(nids: seq[Nid]): Future[?!void] {.async.} =
      expiredNodesReceived = nids
      return success()

    sub = state.events.nodesExpired.subscribe(onExpired)

    state.config.revisitDelayMins = 22

    time = TimeTracker.new(state, store, dht, clock)

    (await time.start()).tryGet()

  teardown:
    (await time.stop()).tryGet()
    await state.events.nodesExpired.unsubscribe(sub)
    state.checkAllUnsubscribed()

  proc onStep() {.async.} =
    (await state.stepper()).tryGet()

  proc createNodeInStore(lastVisit: uint64): Nid =
    let entry = NodeEntry(id: genNid(), lastVisit: lastVisit)
    store.nodesToIterate.add(entry)
    return entry.id

  test "onStep fires nodesExpired event for expired nodes":
    let
      expiredTimestamp = now - ((1 + state.config.revisitDelayMins) * 60).uint64
      expiredNodeId = createNodeInStore(expiredTimestamp)

    await onStep()

    check:
      expiredNodeId in expiredNodesReceived

  test "onStep does not fire nodesExpired event for nodes that are recent":
    let
      recentTimestamp = now - ((state.config.revisitDelayMins - 1) * 60).uint64
      recentNodeId = createNodeInStore(recentTimestamp)

    await onStep()

    check:
      recentNodeId notin expiredNodesReceived

  test "onStep raises routingTable nodes as nodesFound":
    var nodesFound = newSeq[Nid]()
    proc onNodesFound(nids: seq[Nid]): Future[?!void] {.async.} =
      nodesFound = nids
      return success()

    let sub = state.events.nodesFound.subscribe(onNodesFound)

    dht.routingTable.add(nid)

    await onStep()

    check:
      nid in nodesFound

    await state.events.nodesFound.unsubscribe(sub)
