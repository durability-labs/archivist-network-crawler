import pkg/chronos
import pkg/chronicles
import pkg/metrics
import pkg/datastore
import pkg/datastore/typedds
import pkg/stew/byteutils
import pkg/stew/endians2
import pkg/questionable
import pkg/questionable/results

import std/os
import std/times
import std/options
import std/tables
import std/strutils

logScope:
  topics = "list"

type
  OnUpdateMetric = proc(value: int64): void {.gcsafe, raises:[].}
  Entry* = object
    id*: string # will be node ID
    value*: string

  List* = ref object
    name: string
    store: TypedDatastore
    items: seq[Entry]
    onMetric: OnUpdateMetric

proc `$`*(entry: Entry): string =
  entry.id & ":" & entry.value

proc encode(s: Entry): seq[byte] =
  (s.id & ";" & s.value).toBytes()

proc decode(T: type Entry, bytes: seq[byte]): ?!T =
  let s = string.fromBytes(bytes)
  if s.len == 0:
    return success(Entry(id: "", value: ""))

  let tokens = s.split(";")
  if tokens.len != 2:
    return failure("expected 2 tokens")

  success(Entry(
    id: tokens[0],
    value: tokens[1]
  ))

proc saveItem(this: List, item: Entry): Future[?!void] {.async.} =
  without itemKey =? Key.init(this.name / item.id), err:
    return failure(err)
  ? await this.store.put(itemKey, item)
  return success()

proc load*(this: List): Future[?!void] {.async.}= 
  without queryKey =? Key.init(this.name), err:
    return failure(err)
  without iter =? (await query[Entry](this.store, Query.init(queryKey))), err:
    return failure(err)

  while not iter.finished:
    without item =? (await iter.next()), err:
      return failure(err)
    without value =? item.value, err:
      return failure(err)
    if value.id.len > 0:
      this.items.add(value)

  info "Loaded list", name = this.name, items = this.items.len
  return success()

proc new*(
  _: type List,
  name: string,
  store: TypedDatastore,
  onMetric: OnUpdateMetric
): List =
  List(
    name: name,
    store: store,
    items: newSeq[Entry](),
    onMetric: onMetric
  )

proc add*(this: List, item: Entry): Future[?!void] {.async.} =
  this.items.add(item)
  this.onMetric(this.items.len.int64)

  if err =? (await this.saveItem(item)).errorOption:
    return failure(err)
  return success()
