import pkg/questionable/results
import pkg/chronos
import pkg/libp2p

import ./types

type NodeEntry* = object
  id*: Nid
  lastVisit*: uint64

proc `$`*(entry: NodeEntry): string =
  $entry.id & ":" & $entry.lastVisit

proc toBytes*(entry: NodeEntry): seq[byte] =
  var buffer = initProtoBuffer()
  buffer.write(1, $entry.id)
  buffer.write(2, entry.lastVisit)
  buffer.finish()
  return buffer.buffer

proc fromBytes*(_: type NodeEntry, data: openArray[byte]): ?!NodeEntry =
  var
    buffer = initProtoBuffer(data)
    idStr: string
    lastVisit: uint64

  if buffer.getField(1, idStr).isErr:
    return failure("Unable to decode `idStr`")

  if buffer.getField(2, lastVisit).isErr:
    return failure("Unable to decode `lastVisit`")

  return success(NodeEntry(id: Nid.fromStr(idStr), lastVisit: lastVisit))
