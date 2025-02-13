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

    state.config.checkDelayMins = 11
    state.config.expiryDelayMins = 22

    time = TimeTracker.new(state, store, dht, clock)

    (await time.start()).tryGet()

  teardown:
    (await time.stop()).tryGet()
    await state.events.nodesExpired.unsubscribe(sub)
    state.checkAllUnsubscribed()

  proc onStepExpiry() {.async.} =
    (await state.steppers[0]()).tryGet()

  proc onStepRt() {.async.} =
    (await state.steppers[1]()).tryGet()

  proc createNodeInStore(lastVisit: uint64): Nid =
    let entry = NodeEntry(id: genNid(), lastVisit: lastVisit)
    store.nodesToIterate.add(entry)
    return entry.id

  test "start sets steppers for expiry and routingtable load":
    check:
      state.delays[0] == state.config.checkDelayMins.minutes
      state.delays[1] == 30.minutes

  test "onStep fires nodesExpired event for expired nodes":
    let
      expiredTimestamp = now - ((1 + state.config.expiryDelayMins) * 60).uint64
      expiredNodeId = createNodeInStore(expiredTimestamp)

    await onStepExpiry()

    check:
      expiredNodeId in expiredNodesReceived

  test "onStep does not fire nodesExpired event for nodes that are recent":
    let
      recentTimestamp = now - ((state.config.expiryDelayMins - 1) * 60).uint64
      recentNodeId = createNodeInStore(recentTimestamp)

    await onStepExpiry()

    check:
      recentNodeId notin expiredNodesReceived

  test "onStep raises routingTable nodes as nodesFound":
    var nodesFound = newSeq[Nid]()
    proc onNodesFound(nids: seq[Nid]): Future[?!void] {.async.} =
      nodesFound = nids
      return success()

    let sub = state.events.nodesFound.subscribe(onNodesFound)

    dht.routingTable.add(nid)

    await onStepRt()

    check:
      nid in nodesFound

    await state.events.nodesFound.unsubscribe(sub)
