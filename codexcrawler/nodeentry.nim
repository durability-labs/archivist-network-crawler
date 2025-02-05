import pkg/stew/byteutils
import pkg/stew/endians2
import pkg/questionable
import pkg/questionable/results

type NodeEntry* = object
  id*: string # will be node ID
  value*: string

proc `$`*(entry: NodeEntry): string =
  entry.id & ":" & entry.value
