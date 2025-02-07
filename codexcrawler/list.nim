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
import std/os

import ./nodeentry

logScope:
  topics = "list"

type
  OnUpdateMetric = proc(value: int64): void {.gcsafe, raises: [].}

  List* = ref object
    name: string
    store: TypedDatastore
    items: HashSet[NodeEntry]
    onMetric: OnUpdateMetric

proc encode(s: NodeEntry): seq[byte] =
  ($s.id & ";" & s.value).toBytes()

proc decode(T: type NodeEntry, bytes: seq[byte]): ?!T =
  let s = string.fromBytes(bytes)
  if s.len == 0:
    return success(NodeEntry(id: NodeId("0".u256), value: ""))

  let tokens = s.split(";")
  if tokens.len != 2:
    return failure("expected 2 tokens")

  success(NodeEntry(id: NodeId(tokens[0].u256), value: tokens[1]))

proc saveItem(this: List, item: NodeEntry): Future[?!void] {.async.} =
  without itemKey =? Key.init(this.name / $item.id), err:
    return failure(err)
  ?await this.store.put(itemKey, item)
  return success()

proc removeItem(this: List, item: NodeEntry): Future[?!void] {.async.} =
  without itemKey =? Key.init(this.name / $item.id), err:
    return failure(err)
  ?await this.store.delete(itemKey)
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
    if value.value.len > 0:
      this.items.incl(value)

  this.onMetric(this.items.len.int64)
  info "Loaded list", name = this.name, items = this.items.len
  return success()

proc new*(
    _: type List, name: string, store: TypedDatastore, onMetric: OnUpdateMetric
): List =
  List(name: name, store: store, onMetric: onMetric)

proc add*(this: List, item: NodeEntry): Future[?!void] {.async.} =
  this.items.incl(item)
  this.onMetric(this.items.len.int64)

  if err =? (await this.saveItem(item)).errorOption:
    return failure(err)
  return success()

proc pop*(this: List): Future[?!NodeEntry] {.async.} =
  if this.items.len < 1:
    return failure(this.name & "List is empty.")

  let item = this.items.pop()
  if err =? (await this.removeItem(item)).errorOption:
    return failure(err)
  return success(item)

proc len*(this: List): int =
  this.items.len
