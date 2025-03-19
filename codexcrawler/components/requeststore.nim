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
import ../services/clock

const requeststoreName = "requeststore"

logScope:
  topics = "requeststore"

type
  RequestEntry* = object
    id*: Rid
    lastSeen*: uint64

  OnRequestEntry* =
    proc(entry: RequestEntry): Future[?!void] {.async: (raises: []), gcsafe.}

  RequestStore* = ref object of Component
    state: State
    store: TypedDatastore
    clock: Clock

proc `$`*(entry: RequestEntry): string =
  $entry.id

proc toBytes*(entry: RequestEntry): seq[byte] =
  var buffer = initProtoBuffer()
  buffer.write(1, $entry.id)
  buffer.write(2, entry.lastSeen)
  buffer.finish()
  return buffer.buffer

proc fromBytes*(_: type RequestEntry, data: openArray[byte]): ?!RequestEntry =
  var
    buffer = initProtoBuffer(data)
    idStr: string
    lastSeen: uint64

  if buffer.getField(1, idStr).isErr:
    return failure("Unable to decode `idStr`")
  if buffer.getField(2, lastSeen).isErr:
    return failure("Unable to decode `lastSeen`")

  return success(RequestEntry(id: Rid.fromStr(idStr), lastSeen: lastSeen))

proc encode*(e: RequestEntry): seq[byte] =
  e.toBytes()

proc decode*(T: type RequestEntry, bytes: seq[byte]): ?!T =
  if bytes.len < 1:
    return success(RequestEntry(lastSeen: 0))
  return RequestEntry.fromBytes(bytes)

proc update*(s: RequestStore, rid: Rid): Future[?!void] {.async.} =
  without key =? Key.init(requeststoreName / $rid), err:
    error "failed to format key", err = err.msg
    return failure(err)

  let entry = RequestEntry(id: rid, lastSeen: s.clock.now)
  ?await s.store.put(key, entry)
  trace "Request entry updated", id = $rid
  return success()

proc remove*(s: RequestStore, rid: Rid): Future[?!void] {.async.} =
  without key =? Key.init(requeststoreName / $rid), err:
    error "failed to format key", err = err.msg
    return failure(err)

  ?await s.store.delete(key)
  trace "Request entry removed", id = $rid
  return success()

# proc storeNodeIsNew(s: RequestStore, nid: Nid): Future[?!bool] {.async.} =
#   without key =? Key.init(requeststoreName / $nid), err:
#     error "failed to format key", err = err.msg
#     return failure(err)
#   without exists =? (await s.store.has(key)), err:
#     error "failed to check store for key", err = err.msg
#     return failure(err)

#   if not exists:
#     let entry = RequestEntry(id: nid, lastVisit: 0, firstInactive: 0)
#     ?await s.store.put(key, entry)
#     info "New node", nodeId = $nid

#   return success(not exists)

# proc deleteEntry(s: RequestStore, nid: Nid): Future[?!bool] {.async.} =
#   without key =? Key.init(requeststoreName / $nid), err:
#     error "failed to format key", err = err.msg
#     return failure(err)
#   without exists =? (await s.store.has(key)), err:
#     error "failed to check store for key", err = err.msg, key = $key
#     return failure(err)

#   if exists:
#     ?await s.store.delete(key)

#   return success(exists)

# method iterateAll*(
#     s: RequestStore, onNode: OnRequestEntry
# ): Future[?!void] {.async: (raises: []), base.} =
#   without queryKey =? Key.init(requeststoreName), err:
#     error "failed to format key", err = err.msg
#     return failure(err)
#   try:
#     without iter =? (await query[RequestEntry](s.store, Query.init(queryKey))), err:
#       error "failed to create query", err = err.msg
#       return failure(err)

#     while not iter.finished:
#       without item =? (await iter.next()), err:
#         error "failure during query iteration", err = err.msg
#         return failure(err)
#       without value =? item.value, err:
#         error "failed to get value from iterator", err = err.msg
#         return failure(err)

#       if value.lastSeen > 0:
#         ?await onNode(value)

#       await sleepAsync(1.millis)
#   except CatchableError as exc:
#     return failure(exc.msg)

#   return success()

method start*(s: RequestStore): Future[?!void] {.async.} =
  info "Starting..."
  return success()

method stop*(s: RequestStore): Future[?!void] {.async.} =
  return success()

proc new*(
    T: type RequestStore, state: State, store: TypedDatastore, clock: Clock
): RequestStore =
  RequestStore(state: state, store: store, clock: clock)

proc createRequestStore*(state: State, clock: Clock): ?!RequestStore =
  without ds =? createTypedDatastore(state.config.dataDir / "requeststore"), err:
    error "Failed to create typed datastore for request store", err = err.msg
    return failure(err)

  return success(RequestStore.new(state, ds, clock))
