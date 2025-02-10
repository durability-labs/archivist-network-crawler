import pkg/stew/byteutils
import pkg/stew/endians2
import pkg/questionable
import pkg/codexdht

type Nid* = NodeId

proc `$`*(nid: Nid): string =
  $(NodeId(nid))

proc fromStr*(T: type Nid, s: string): Nid =
  Nid(UInt256.fromHex(s))
