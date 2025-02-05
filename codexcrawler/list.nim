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
    value*: string

  List* = ref object
    name: string
    store: TypedDatastore
    items: seq[Entry]
    onMetric: OnUpdateMetric
    lastSaveUtc: DateTime

proc encode(i: int): seq[byte] =
  @(cast[uint64](i).toBytesBE)

proc decode(T: type int, bytes: seq[byte]): ?!T =
  if bytes.len >= sizeof(uint64):
    success(cast[int](uint64.fromBytesBE(bytes)))
  else:
    failure("not enough bytes to decode int")

proc encode(s: Entry): seq[byte] =
  s.value.toBytes()

proc decode(T: type Entry, bytes: seq[byte]): ?!T =
  success(Entry(value: string.fromBytes(bytes)))

proc save(this: List): Future[?!void] {.async.}= 
  let countKey = Key.init(this.name / "count").tryGet
  trace "countkey", key = $countKey, count = this.items.len
  ? await this.store.put(countKey, this.items.len)

  for i in 0 ..< this.items.len:
    let itemKey = Key.init(this.name / $i).tryGet
    trace "itemKey", key = $itemKey, iter = i
    ? await this.store.put(itemKey, this.items[i])

  info "List saved", name = this.name
  return success()

proc load*(this: List): Future[?!void] {.async.}= 
  let countKey = Key.init(this.name / "count").tryGet
  without hasKey =? (await this.store.has(countKey)), err:
    return failure (err)
  if hasKey:
    without count =? (await get[int](this.store, countKey)), err:
      return failure(err)

    for i in 0 ..< count:
      let itemKey = Key.init(this.name / $i).tryGet
      without entry =? (await get[Entry](this.store, itemKey)), err:
        return failure(err)
      this.items.add(entry)

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
    onMetric: onMetric,
    lastSaveUtc: now().utc
  )

proc add*(this: List, item: Entry): Future[?!void] {.async.} =
  this.items.add(item)
  this.onMetric(this.items.len.int64)

  if this.lastSaveUtc < now().utc - initDuration(seconds = 10):
    this.lastSaveUtc = now().utc
    trace "Saving changes...", name = this.name
    if err =? (await this.save()).errorOption:
      error "Failed to save list", name = this.name
      return failure("Failed to save list")
  return success()