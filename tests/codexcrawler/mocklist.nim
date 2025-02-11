import pkg/chronos
import pkg/questionable/results

import ../../codexcrawler/types
import ../../codexcrawler/list

type
  MockList* = ref object of List
    loadCalled*: bool
    added*: seq[Nid]
    addSuccess*: bool
    removed*: seq[Nid]
    removeSuccess*: bool

method load*(this: MockList): Future[?!void] {.async.} =
  this.loadCalled = true

method add*(this: MockList, nid: Nid): Future[?!void] {.async.} =
  this.added.add(nid)
  if this.addSuccess:
    return success()
  return failure("test failure")

method remove*(this: MockList, nid: Nid): Future[?!void] {.async.} =
  this.removed.add(nid)
  if this.removeSuccess:
    return success()
  return failure("test failure")

proc createMockList*(): MockList =
  MockList(
    loadCalled: false,
    added: newSeq[Nid](),
    addSuccess: true,
    removed: newSeq[Nid](),
    removeSuccess: true
  )
