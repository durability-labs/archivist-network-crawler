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
import ../helpers

suite "ChainMetrics":
  var
    state: MockState
    metrics: MockMetrics
    store: MockRequestStore
    marketplace: MockMarketplaceService
    chain: ChainMetrics

  setup:
    state = createMockState()
    metrics = createMockMetrics()
    store = createMockRequestStore()
    marketplace = createMockMarketplaceService()

    chain = ChainMetrics.new(state, metrics, store, marketplace)

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

  test "onStep should remove non-running requests from request store":
    let rid = genRid()
    store.iterateEntries.add(RequestEntry(id: rid))

    marketplace.requestInfoReturns = none(RequestInfo)

    await onStep()

    check:
      marketplace.requestInfoRid == rid
      store.removeRid == rid

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
