import pkg/stew/byteutils
import pkg/stint/io
import pkg/questionable/results
import pkg/codexdht
import pkg/libp2p

type Nid* = NodeId

proc `$`*(nid: Nid): string =
  nid.toHex()

proc fromStr*(T: type Nid, s: string): Nid =
  Nid(UInt256.fromHex(s))

proc toBytes*(nid: Nid): seq[byte] =
  var buffer = initProtoBuffer()
  buffer.write(1, $nid)
  buffer.finish()
  return buffer.buffer

proc fromBytes*(_: type Nid, data: openArray[byte]): ?!Nid =
  var
    buffer = initProtoBuffer(data)
    idStr: string

  if buffer.getField(1, idStr).isErr:
    return failure("Unable to decode `idStr`")

  return success(Nid.fromStr(idStr))
