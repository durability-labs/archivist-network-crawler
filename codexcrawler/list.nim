import pkg/chronos
import pkg/chronicles
import pkg/metrics
import pkg/datastore
import pkg/datastore/typedds
import pkg/questionable
import pkg/questionable/results

import std/os

import ./nodeentry

logScope:
  topics = "list"

type
  OnUpdateMetric = proc(value: int64): void {.gcsafe, raises: [].}

  List* = ref object
    name: string
    store: TypedDatastore
    items: seq[NodeEntry]
    onMetric: OnUpdateMetric

proc saveItem(this: List, item: NodeEntry): Future[?!void] {.async.} =
  without itemKey =? Key.init(this.name / item.id), err:
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
    if value.id.len > 0:
      this.items.add(value)

  info "Loaded list", name = this.name, items = this.items.len
  return success()

proc new*(
    _: type List, name: string, store: TypedDatastore, onMetric: OnUpdateMetric
): List =
  List(name: name, store: store, items: newSeq[NodeEntry](), onMetric: onMetric)

proc add*(this: List, item: NodeEntry): Future[?!void] {.async.} =
  this.items.add(item)
  this.onMetric(this.items.len.int64)

  if err =? (await this.saveItem(item)).errorOption:
    return failure(err)
  return success()
