import pkg/chronos
import pkg/questionable
import pkg/questionable/results
import pkg/asynctest/chronos/unittest
import std/sequtils

import ../../../codexcrawler/components/chainmetrics
import ../../../codexcrawler/services/marketplace/market
import ../../../codexcrawler/types
import ../../../codexcrawler/state
import ../mocks/mockstate
import ../mocks/mockmetrics
import ../mocks/mockmarketplace
import ../helpers

suite "ChainMetrics":
  var
    state: MockState
    metrics: MockMetrics
    marketplace: MockMarketplaceService
    chain: ChainMetrics

  setup:
    state = createMockState()
    metrics = createMockMetrics()
    marketplace = createMockMarketplaceService()

    metrics.slotFill = -1
    chain = ChainMetrics.new(state, metrics, marketplace)

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

  test "onStep is not activated when config.marketplaceEnable is false":
    # Recreate chainMetrics, reset mockstate:
    (await chain.stop()).tryGet()
    state.steppers = @[]
    # disable marketplace:
    state.config.marketplaceEnable = false
    (await chain.start()).tryGet()

    check:
      state.steppers.len == 0

  test "step should not call setSlotFill when getRecentSlotFillEvents fails":
    let testValue = -123
    metrics.slotFill = testValue

    marketplace.recentSlotFillEventsReturn = seq[SlotFilled].failure("testfailure")

    await onStep()

    check:
      metrics.slotFill == testValue

  test "step should setSlotFill to zero when getRecentSlotFillEvents returns empty seq":
    metrics.slotFill = -123

    marketplace.recentSlotFillEventsReturn = success(newSeq[SlotFilled]())

    await onStep()

    check:
      metrics.slotFill == 0

  test "step should setSlotFill to the length of seq returned from getRecentSlotFillEvents":
    let fills = @[SlotFilled(), SlotFilled(), SlotFilled(), SlotFilled()]

    marketplace.recentSlotFillEventsReturn = success(fills)

    await onStep()

    check:
      metrics.slotFill == fills.len
