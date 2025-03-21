import std/sequtils
import pkg/questionable/results
import pkg/chronos

import ../../../codexcrawler/components/requeststore
import ../../../codexcrawler/types

type MockRequestStore* = ref object of RequestStore
  updateRid*: Rid
  removeRid*: Rid
  iterateEntries*: seq[RequestEntry]

method update*(s: MockRequestStore, rid: Rid): Future[?!void] {.async: (raises: []).} =
  s.updateRid = rid
  return success()

method remove*(s: MockRequestStore, rid: Rid): Future[?!void] {.async: (raises: []).} =
  s.removeRid = rid
  return success()

method iterateAll*(
    s: MockRequestStore, onNode: OnRequestEntry
): Future[?!void] {.async: (raises: []).} =
  for entry in s.iterateEntries:
    ?await onNode(entry)
  return success()

proc createMockRequestStore*(): MockRequestStore =
  MockRequestStore(iterateEntries: newSeq[RequestEntry]())
