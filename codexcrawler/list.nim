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
import pkg/codexdht

import std/sets
import std/strutils
import std/sequtils
import std/os

import ./nodeentry

logScope:
  topics = "list"

type
  OnUpdateMetric = proc(value: int64): void {.gcsafe, raises: [].}
  OnItem = proc(item: NodeEntry): void {.gcsafe, raises: [].}

  List* = ref object
    name: string
    store: TypedDatastore
    items: seq[NodeEntry]
    onMetric: OnUpdateMetric

proc encode(s: NodeEntry): seq[byte] =
  s.toBytes()

proc decode(T: type NodeEntry, bytes: seq[byte]): ?!T =
  if bytes.len < 1:
    return success(NodeEntry(id: UInt256.fromHex("0"), lastVisit: 0.uint64))
  return NodeEntry.fromBytes(bytes)

proc saveItem(this: List, item: NodeEntry): Future[?!void] {.async.} =
  without itemKey =? Key.init(this.name / $item.id), err:
    return failure(err)
  ?await this.store.put(itemKey, item)
  return success()

proc load*(this: List): Future[?!void] {.async.} =
  without queryKey =? Key.init(this.name), err:
    return failure(err)
  without iter =? (await query[NodeEntry](this.store, Query.init(queryKey))), err:
    return failure(err)

  while not iter.finished:
    without item =? (await iter.next()), err:
      return failure(err)
    without value =? item.value, err:
      return failure(err)
    if value.id > 0 or value.lastVisit > 0:
      this.items.add(value)

  this.onMetric(this.items.len.int64)
  info "Loaded list", name = this.name, items = this.items.len
  return success()

proc new*(
    _: type List, name: string, store: TypedDatastore, onMetric: OnUpdateMetric
): List =
  List(name: name, store: store, onMetric: onMetric)

proc contains*(this: List, nodeId: NodeId): bool =
  this.items.anyIt(it.id == nodeId)

proc contains*(this: List, item: NodeEntry): bool =
  this.contains(item.id)

proc add*(this: List, item: NodeEntry): Future[?!void] {.async.} =
  if this.contains(item):
    return success()

  this.items.add(item)
  this.onMetric(this.items.len.int64)

  if err =? (await this.saveItem(item)).errorOption:
    return failure(err)
  return success()

proc remove*(this: List, item: NodeEntry): Future[?!void] {.async.} =
  if this.items.len < 1:
    return failure(this.name & "List is empty.")

  this.items.keepItIf(item.id != it.id)
  without itemKey =? Key.init(this.name / $item.id), err:
    return failure(err)
  ?await this.store.delete(itemKey)
  this.onMetric(this.items.len.int64)
  return success()

proc pop*(this: List): Future[?!NodeEntry] {.async.} =
  if this.items.len < 1:
    return failure(this.name & "List is empty.")

  let item = this.items[0]

  if err =? (await this.remove(item)).errorOption:
    return failure(err)
  return success(item)

proc len*(this: List): int =
  this.items.len

proc iterateAll*(this: List, onItem: OnItem) {.async.} =
  for item in this.items:
    onItem(item)
    await sleepAsync(1.millis)
