import pkg/chronos
import pkg/questionable
import pkg/questionable/results
import pkg/asynctest/chronos/unittest

import ../../../codexcrawler/components/crawler
import ../../../codexcrawler/services/dht
import ../../../codexcrawler/utils/asyncdataevent
import ../../../codexcrawler/types
import ../../../codexcrawler/state
import ../mocks/mockstate
import ../mocks/mockdht
import ../mocks/mocktodolist
import ../helpers

suite "Crawler":
  var
    nid1: Nid
    nid2: Nid
    state: MockState
    todo: MockTodoList
    dht: MockDht
    crawler: Crawler

  setup:
    nid1 = genNid()
    nid2 = genNid()
    state = createMockState()
    todo = createMockTodoList()
    dht = createMockDht()

    crawler = Crawler.new(state, dht, todo)

    (await crawler.start()).tryGet()

  teardown:
    (await crawler.stop()).tryGet()
    state.checkAllUnsubscribed()

  proc onStep() {.async.} =
    (await state.steppers[0]()).tryGet()

  proc responsive(nid: Nid): GetNeighborsResponse =
    GetNeighborsResponse(isResponsive: true, nodeIds: @[nid])

  proc unresponsive(nid: Nid): GetNeighborsResponse =
    GetNeighborsResponse(isResponsive: false, nodeIds: @[nid])

  test "onStep should pop a node from the todoList and getNeighbors for it":
    todo.popReturn = success(nid1)
    dht.getNeighborsReturn = success(responsive(nid1))

    await onStep()

    check:
      !(dht.getNeighborsArg) == nid1

  test "nodes returned by getNeighbors are raised as nodesFound":
    var nodesFound = newSeq[Nid]()
    proc onNodesFound(nids: seq[Nid]): Future[?!void] {.async.} =
      nodesFound = nids
      return success()

    let sub = state.events.nodesFound.subscribe(onNodesFound)

    todo.popReturn = success(nid1)
    dht.getNeighborsReturn = success(responsive(nid2))

    await onStep()

    check:
      nid2 in nodesFound

    await state.events.nodesFound.unsubscribe(sub)

  test "responsive result from getNeighbors raises the node as successful dhtNodeCheck":
    var checkEvent = DhtNodeCheckEventData()
    proc onCheck(event: DhtNodeCheckEventData): Future[?!void] {.async.} =
      checkEvent = event
      return success()

    let sub = state.events.dhtNodeCheck.subscribe(onCheck)

    todo.popReturn = success(nid1)
    dht.getNeighborsReturn = success(responsive(nid2))

    await onStep()

    check:
      checkEvent.id == nid1
      checkEvent.isOk == true

    await state.events.dhtNodeCheck.unsubscribe(sub)

  test "unresponsive result from getNeighbors raises the node as unsuccessful dhtNodeCheck":
    var checkEvent = DhtNodeCheckEventData()
    proc onCheck(event: DhtNodeCheckEventData): Future[?!void] {.async.} =
      checkEvent = event
      return success()

    let sub = state.events.dhtNodeCheck.subscribe(onCheck)

    todo.popReturn = success(nid1)
    dht.getNeighborsReturn = success(unresponsive(nid2))

    await onStep()

    check:
      checkEvent.id == nid1
      checkEvent.isOk == false

    await state.events.dhtNodeCheck.unsubscribe(sub)
