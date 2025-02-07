import pkg/stew/byteutils
import pkg/stew/endians2
import pkg/questionable
import pkg/questionable/results
import pkg/codexdht

type NodeEntry* = object
  id*: NodeId
  value*: string # todo: will be last-checked timestamp

proc `$`*(entry: NodeEntry): string =
  $entry.id & ":" & entry.value
