import std/os
import pkg/chronos
import pkg/questionable/results
import pkg/asynctest/chronos/unittest
import pkg/datastore/typedds

import ../../../codexcrawler/components/nodestore
import ../../../codexcrawler/utils/datastoreutils
import ../../../codexcrawler/utils/asyncdataevent
import ../../../codexcrawler/types
import ../mockstate
import ../helpers

suite "Nodestore":
  let
    dsPath = getTempDir() / "testds"
    nodestoreName = "nodestore"

  var 
    ds: TypedDatastore
    state: MockState
    store: NodeStore

  setup:
    ds = createTypedDatastore(dsPath).tryGet()
    state = createMockState()

    store = NodeStore.new(
      state, ds
    )

    (await store.start()).tryGet()

  teardown:
    (await store.stop()).tryGet()
    (await ds.close()).tryGet()
    state.checkAllUnsubscribed()
    removeDir(dsPath)

  test "nodeEntry encoding":
    let entry = NodeEntry(
      id: genNid(),
      lastVisit: 123.uint64
    )

    let
      bytes = entry.encode()
      decoded = NodeEntry.decode(bytes).tryGet()

    check:
      entry.id == decoded.id
      entry.lastVisit == decoded.lastVisit

  test "nodesFound event should store nodes":
    let 
      nid = genNid()
      expectedKey = Key.init(nodestoreName / $nid).tryGet()

    (await state.events.nodesFound.fire(@[nid])).tryGet()

    check:
      (await ds.has(expectedKey)).tryGet()
    
    let entry = (await get[NodeEntry](ds, expectedKey)).tryGet()
    check:
      entry.id == nid

  test "nodesFound event should fire newNodesDiscovered":
    var newNodes = newSeq[Nid]()
    proc onNewNodes(nids: seq[Nid]): Future[?!void] {.async.} =
      newNodes = nids
      return success()

    let 
      sub = state.events.newNodesDiscovered.subscribe(onNewNodes)
      nid = genNid()

    (await state.events.nodesFound.fire(@[nid])).tryGet()

    check:
      newNodes == @[nid]

    await state.events.newNodesDiscovered.unsubscribe(sub)
    
  test "nodesFound event should not fire newNodesDiscovered for previously seen nodes":
    let 
      nid = genNid()

    # Make nid known first. Then subscribe.
    (await state.events.nodesFound.fire(@[nid])).tryGet()

    var
      newNodes = newSeq[Nid]()
      count = 0
    proc onNewNodes(nids: seq[Nid]): Future[?!void] {.async.} =
      newNodes = nids
      inc count
      return success()

    let 
      sub = state.events.newNodesDiscovered.subscribe(onNewNodes)
      
    # Firing the event again should not trigger newNodesDiscovered for nid
    (await state.events.nodesFound.fire(@[nid])).tryGet()

    check:
      newNodes.len == 0
      count == 0

    await state.events.newNodesDiscovered.unsubscribe(sub)

  test "iterateAll yields all known nids":
    let 
      nid1 = genNid()
      nid2 = genNid()
      nid3 = genNid()
      
    (await state.events.nodesFound.fire(@[nid1, nid2, nid3])).tryGet()

    var iterNodes = newSeq[Nid]()
    proc onNode(entry: NodeEntry): Future[?!void] {.async: (raises: []), gcsafe.} =
      iterNodes.add(entry.id)
      return success()

    (await store.iterateAll(onNode)).tryGet()

    check:
      nid1 in iterNodes
      nid2 in iterNodes
      nid3 in iterNodes
