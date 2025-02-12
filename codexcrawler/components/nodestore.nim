import std/os
import pkg/datastore
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

const nodestoreName = "nodestore"

logScope:
  topics = "nodestore"

type
  NodeEntry* = object
    id*: Nid
    lastVisit*: uint64

  OnNodeEntry* = proc(item: NodeEntry): Future[?!void] {.async: (raises: []), gcsafe.}

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

proc storeNodeIsNew(s: NodeStore, nid: Nid): Future[?!bool] {.async.} =
  without key =? Key.init(nodestoreName / $nid), err:
    return failure(err)
  without exists =? (await s.store.has(key)), err:
    return failure(err)

  if not exists:
    let entry = NodeEntry(id: nid, lastVisit: 0)
    ?await s.store.put(key, entry)

  return success(not exists)

proc fireNewNodesDiscovered(s: NodeStore, nids: seq[Nid]): Future[?!void] {.async.} =
  await s.state.events.newNodesDiscovered.fire(nids)

proc processFoundNodes(s: NodeStore, nids: seq[Nid]): Future[?!void] {.async.} =
  var newNodes = newSeq[Nid]()
  for nid in nids:
    without isNew =? (await s.storeNodeIsNew(nid)), err:
      return failure(err)
    if isNew:
      newNodes.add(nid)

  if newNodes.len > 0:
    trace "Discovered new nodes", newNodes = newNodes.len
    ?await s.fireNewNodesDiscovered(newNodes)
  return success()

method iterateAll*(
    s: NodeStore, onNode: OnNodeEntry
): Future[?!void] {.async: (raises: []), base.} =
  without queryKey =? Key.init(nodestoreName), err:
    return failure(err)
  try:
    without iter =? (await query[NodeEntry](s.store, Query.init(queryKey))), err:
      return failure(err)

    while not iter.finished:
      without item =? (await iter.next()), err:
        return failure(err)
      without value =? item.value, err:
        return failure(err)

      ?await onNode(value)
  except CatchableError as exc:
    return failure(exc.msg)

  return success()

method start*(s: NodeStore): Future[?!void] {.async.} =
  info "Starting..."

  proc onNodesFound(nids: seq[Nid]): Future[?!void] {.async.} =
    return await s.processFoundNodes(nids)

  s.sub = s.state.events.nodesFound.subscribe(onNodesFound)
  return success()

method stop*(s: NodeStore): Future[?!void] {.async.} =
  await s.state.events.nodesFound.unsubscribe(s.sub)
  return success()

proc new*(T: type NodeStore, state: State, store: TypedDatastore): NodeStore =
  NodeStore(state: state, store: store)

proc createNodeStore*(state: State): ?!NodeStore =
  without ds =? createTypedDatastore(state.config.dataDir / "nodestore"), err:
    error "Failed to create typed datastore for node store", err = err.msg
    return failure(err)

  return success(NodeStore.new(state, ds))
