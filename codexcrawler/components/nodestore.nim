import std/os
import pkg/datastore/typedds
import pkg/questionable/results
import pkg/chronicles
import pkg/chronos
import pkg/libp2p

import ../types
import ../component
import ../state
import ../utils/datastoreutils
import ../utils/asyncdataevent

type
  OnNodeId = proc(item: Nid): Future[?!void] {.async: (raises: []), gcsafe.}

  NodeEntry* = object
    id*: Nid
    lastVisit*: uint64

  NodeStore* = ref object of Component
    state: State
    store: TypedDatastore
    sub: AsyncDataEventSubscription

proc `$`*(entry: NodeEntry): string =
  $entry.id & ":" & $entry.lastVisit

proc toBytes*(entry: NodeEntry): seq[byte] =
  var buffer = initProtoBuffer()
  buffer.write(1, $entry.id)
  buffer.write(2, entry.lastVisit)
  buffer.finish()
  return buffer.buffer

proc fromBytes*(_: type NodeEntry, data: openArray[byte]): ?!NodeEntry =
  var
    buffer = initProtoBuffer(data)
    idStr: string
    lastVisit: uint64

  if buffer.getField(1, idStr).isErr:
    return failure("Unable to decode `idStr`")

  if buffer.getField(2, lastVisit).isErr:
    return failure("Unable to decode `lastVisit`")

  return success(NodeEntry(id: Nid.fromStr(idStr), lastVisit: lastVisit))

proc encode*(e: NodeEntry): seq[byte] =
  e.toBytes()

proc decode*(T: type NodeEntry, bytes: seq[byte]): ?!T =
  if bytes.len < 1:
    return success(NodeEntry(id: Nid.fromStr("0"), lastVisit: 0.uint64))
  return NodeEntry.fromBytes(bytes)

proc processFoundNodes(s: NodeStore, nids: seq[Nid]): Future[?!void] {.async.} =
  # put the nodes in the store.
  # track all new ones, if any, raise newNodes event.
  return success()

proc iterateAll*(s: NodeStore, onNodeId: OnNodeId) {.async.} =
  discard
  # query iterator, yield items to callback.
  # for item in this.items:
  #   onItem(item)
  #   await sleepAsync(1.millis)

method start*(s: NodeStore): Future[?!void] {.async.} =
  info "Starting nodestore..."

  proc onNodesFound(nids: seq[Nid]): Future[?!void] {.async.} =
    return await s.processFoundNodes(nids)

  s.sub = s.state.events.nodesFound.subscribe(onNodesFound)
  return success()

method stop*(s: NodeStore): Future[?!void] {.async.} =
  await s.state.events.nodesFound.unsubscribe(s.sub)
  return success()

proc new*(
    T: type NodeStore,
    state: State,
    store: TypedDatastore
): NodeStore =
  NodeStore(
    state: state,
    store: store
  )

proc createNodeStore*(state: State): ?!NodeStore =
  without ds =? createTypedDatastore(state.config.dataDir / "nodestore"), err:
    error "Failed to create typed datastore for node store", err = err.msg
    return failure(err)

  return success(NodeStore.new(state, ds))
