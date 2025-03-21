import pkg/chronos
import pkg/questionable
import pkg/questionable/results
import pkg/asynctest/chronos/unittest

import ../../../codexcrawler/components/chainmetrics
import ../../../codexcrawler/components/requeststore
import ../../../codexcrawler/services/marketplace
import ../../../codexcrawler/types
import ../mocks/mockstate
import ../mocks/mockmetrics
import ../mocks/mockrequeststore
import ../mocks/mockmarketplace
import ../mocks/mockclock
import ../helpers

suite "ChainMetrics":
  var
    state: MockState
    metrics: MockMetrics
    store: MockRequestStore
    marketplace: MockMarketplaceService
    clock: MockClock
    chain: ChainMetrics

  setup:
    state = createMockState()
    metrics = createMockMetrics()
    store = createMockRequestStore()
    marketplace = createMockMarketplaceService()
    clock = createMockClock()

    chain = ChainMetrics.new(state, metrics, store, marketplace, clock)

    (await chain.start()).tryGet()

  teardown:
    (await chain.stop()).tryGet()
    state.checkAllUnsubscribed()

  proc onStep() {.async.} =
    (await state.steppers[0]()).tryGet()

  test "start should start stepper for 10 minutes":
    check:
      state.delays.len == 1
      state.delays[0] == 10.minutes

  test "onStep should remove old non-running requests from request store":
    let rid = genRid()
    let oneDay = (60 * 60 * 24).uint64
    store.iterateEntries.add(RequestEntry(id: rid, lastSeen: 100.uint64))

    clock.setNow = 100 + oneDay + 1
    marketplace.requestInfoReturns = none(RequestInfo)

    await onStep()

    check:
      marketplace.requestInfoRid == rid
      store.removeRid == rid

  test "onStep should not remove recent non-running requests from request store":
    let rid = genRid()
    let now = 123456789.uint64
    store.iterateEntries.add(RequestEntry(id: rid, lastSeen: now - 1))

    clock.setNow = now
    marketplace.requestInfoReturns = none(RequestInfo)

    await onStep()

    check:
      marketplace.requestInfoRid == rid
      not (store.removeRid == rid)

  test "onStep should count the number of active requests":
    let rid1 = genRid()
    let rid2 = genRid()
    store.iterateEntries.add(RequestEntry(id: rid1))
    store.iterateEntries.add(RequestEntry(id: rid2))

    marketplace.requestInfoReturns = some(RequestInfo())

    await onStep()

    check:
      metrics.requests == 2

  test "onStep should count the number of active slots":
    let rid = genRid()
    store.iterateEntries.add(RequestEntry(id: rid))

    let info = RequestInfo(slots: 123)
    marketplace.requestInfoReturns = some(info)

    await onStep()

    check:
      metrics.slots == info.slots.int

  test "onStep should count the total size of active slots":
    let rid = genRid()
    store.iterateEntries.add(RequestEntry(id: rid))

    let info = RequestInfo(slots: 12, slotSize: 23)
    marketplace.requestInfoReturns = some(info)

    await onStep()

    check:
      metrics.totalSize == (info.slots * info.slotSize).int
