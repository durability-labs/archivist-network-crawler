import std/sequtils
import pkg/questionable/results
import pkg/chronos

import ../../../codexcrawler/components/nodestore

type MockNodeStore* = ref object of NodeStore
  nodesToIterate*: seq[NodeEntry]

method iterateAll*(
    s: MockNodeStore, onNode: OnNodeEntry
): Future[?!void] {.async: (raises: []).} =
  for node in s.nodesToIterate:
    ?await onNode(node)
  return success()

method start*(s: MockNodeStore): Future[?!void] {.async.} =
  return success()

method stop*(s: MockNodeStore): Future[?!void] {.async.} =
  return success()

proc createMockNodeStore*(): MockNodeStore =
  MockNodeStore(nodesToIterate: newSeq[NodeEntry]())
