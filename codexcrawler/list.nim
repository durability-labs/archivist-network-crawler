import pkg/chronos
import pkg/chronicles
import pkg/metrics
import pkg/datastore
import pkg/datastore/typedds
import pkg/stew/byteutils
import pkg/stew/endians2
import pkg/questionable
import pkg/questionable/results
import pkg/stint

import std/sets
import std/sequtils
import std/os

import ./types

logScope:
  topics = "list"

type
  OnUpdateMetric = proc(value: int64): void {.gcsafe, raises: [].}

  List* = ref object
    name: string
    store: TypedDatastore
    items: HashSet[Nid]
    onMetric: OnUpdateMetric
    emptySignal: ?Future[void]

proc encode(s: Nid): seq[byte] =
  s.toBytes()

proc decode(T: type Nid, bytes: seq[byte]): ?!T =
  if bytes.len < 1:
    return success(Nid.fromStr("0"))
  return Nid.fromBytes(bytes)

proc saveItem(this: List, item: Nid): Future[?!void] {.async.} =
  without itemKey =? Key.init(this.name / $item), err:
    return failure(err)
  ?await this.store.put(itemKey, item)
  return success()

proc load*(this: List): Future[?!void] {.async.} =
  without queryKey =? Key.init(this.name), err:
    return failure(err)
  without iter =? (await query[Nid](this.store, Query.init(queryKey))), err:
    return failure(err)

  while not iter.finished:
    without item =? (await iter.next()), err:
      return failure(err)
    without value =? item.value, err:
      return failure(err)
    if value > 0:
      this.items.incl(value)

  this.onMetric(this.items.len.int64)
  info "Loaded list", name = this.name, items = this.items.len
  return success()

proc new*(
    _: type List, name: string, store: TypedDatastore, onMetric: OnUpdateMetric
): List =
  List(name: name, store: store, onMetric: onMetric)

proc contains*(this: List, nid: Nid): bool =
  this.items.anyIt(it == nid)

proc add*(this: List, nid: Nid): Future[?!void] {.async.} =
  if this.contains(nid):
    return success()

  this.items.incl(nid)
  this.onMetric(this.items.len.int64)

  if err =? (await this.saveItem(nid)).errorOption:
    return failure(err)

  if s =? this.emptySignal:
    trace "List no longer empty.", name = this.name
    s.complete()
    this.emptySignal = Future[void].none

  return success()

proc remove*(this: List, nid: Nid): Future[?!void] {.async.} =
  if this.items.len < 1:
    return failure(this.name & "List is empty.")

  this.items.excl(nid)
  without itemKey =? Key.init(this.name / $nid), err:
    return failure(err)
  ?await this.store.delete(itemKey)
  this.onMetric(this.items.len.int64)
  return success()

proc pop*(this: List): Future[?!Nid] {.async.} =
  if this.items.len < 1:
    trace "List is empty. Waiting for new items...", name = this.name
    let signal = newFuture[void]("list.emptySignal")
    this.emptySignal = some(signal)
    await signal.wait(1.hours)
    if this.items.len < 1:
      return failure(this.name & "List is empty.")

  let item = this.items.pop()

  if err =? (await this.remove(item)).errorOption:
    return failure(err)
  return success(item)

proc len*(this: List): int =
  this.items.len

