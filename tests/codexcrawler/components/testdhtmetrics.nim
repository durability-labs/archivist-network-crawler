import std/os
import pkg/chronos
import pkg/questionable/results
import pkg/asynctest/chronos/unittest
import pkg/datastore/typedds

import ../../../codexcrawler/components/dhtmetrics
import ../../../codexcrawler/utils/asyncdataevent
import ../../../codexcrawler/types
import ../../../codexcrawler/state
import ../mockstate
import ../mocklist
import ../helpers

suite "DhtMetrics":
  var
    nid: Nid
    state: MockState
    okList: MockList
    nokList: MockList
    dhtmetrics: DhtMetrics

  setup:
    nid = genNid()
    state = createMockState()
    okList = createMockList()
    nokList = createMockList()

    dhtmetrics = DhtMetrics.new(
      state,
      okList,
      nokList
    )

    (await dhtmetrics.start()).tryGet()

  teardown:
    (await dhtmetrics.stop()).tryGet()
    state.checkAllUnsubscribed()

  proc fireDhtNodeCheckEvent(isOk: bool) {.async.} =
    let
      event = DhtNodeCheckEventData(
        id: nid,
        isOk: isOk
      )

    (await state.events.dhtNodeCheck.fire(event)).tryGet()

  test "dhtmetrics start should load both lists":
    (await dhtmetrics.start()).tryGet()

    check:
      okList.loadCalled
      nokList.loadCalled

  test "dhtNodeCheck event should add node to okList if check is successful":
    await fireDhtNodeCheckEvent(true)

    check:
      nid in okList.added 

  test "dhtNodeCheck event should add node to nokList if check has failed":
    await fireDhtNodeCheckEvent(false)

    check:
      nid in nokList.added 

  test "dhtNodeCheck event should remove node from nokList if check is successful":
    await fireDhtNodeCheckEvent(true)

    check:
      nid in nokList.removed

  test "dhtNodeCheck event should remove node from okList if check has failed":
    await fireDhtNodeCheckEvent(false)

    check:
      nid in okList.removed
