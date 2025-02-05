import pkg/stew/byteutils
import pkg/stew/endians2
import pkg/questionable
import pkg/questionable/results

type NodeEntry* = object
  id*: string # will be node ID
  value*: string

proc `$`*(entry: NodeEntry): string =
  entry.id & ":" & entry.value

proc encode(s: NodeEntry): seq[byte] =
  (s.id & ";" & s.value).toBytes()

proc decode(T: type NodeEntry, bytes: seq[byte]): ?!T =
  let s = string.fromBytes(bytes)
  if s.len == 0:
    return success(NodeEntry(id: "", value: ""))

  let tokens = s.split(";")
  if tokens.len != 2:
    return failure("expected 2 tokens")

  success(NodeEntry(id: tokens[0], value: tokens[1]))
