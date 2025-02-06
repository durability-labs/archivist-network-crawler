import std/net
import pkg/chronicles
import pkg/chronos
import pkg/libp2p
import pkg/questionable
import pkg/questionable/results
import pkg/codexdht/discv5/[routing_table, protocol as discv5]
from pkg/nimcrypto import keccak256

import ./rng

export discv5

logScope:
  topics = "dht"

type Dht* = ref object
  protocol*: discv5.Protocol
  key: PrivateKey
  peerId: PeerId
  announceAddrs*: seq[MultiAddress]
  providerRecord*: ?SignedPeerRecord
  dhtRecord*: ?SignedPeerRecord

# proc toNodeId*(cid: Cid): NodeId =
#   ## Cid to discovery id
#   ##

#   readUintBE[256](keccak256.digest(cid.data.buffer).data)

# proc toNodeId*(host: ca.Address): NodeId =
#   ## Eth address to discovery id
#   ##

#   readUintBE[256](keccak256.digest(host.toArray).data)

proc findPeer*(d: Dht, peerId: PeerId): Future[?PeerRecord] {.async.} =
  trace "protocol.resolve..."
  ## Find peer using the given Discovery object
  ##
  let node = await d.protocol.resolve(toNodeId(peerId))

  return
    if node.isSome():
      node.get().record.data.some
    else:
      PeerRecord.none

method removeProvider*(d: Dht, peerId: PeerId): Future[void] {.base, gcsafe.} =
  trace "Removing provider", peerId
  d.protocol.removeProvidersLocal(peerId)

proc updateAnnounceRecord*(d: Dht, addrs: openArray[MultiAddress]) =
  d.announceAddrs = @addrs

  trace "Updating announce record", addrs = d.announceAddrs
  d.providerRecord = SignedPeerRecord
    .init(d.key, PeerRecord.init(d.peerId, d.announceAddrs))
    .expect("Should construct signed record").some

  if not d.protocol.isNil:
    d.protocol.updateRecord(d.providerRecord).expect("Should update SPR")

proc updateDhtRecord*(d: Dht, addrs: openArray[MultiAddress]) =
  trace "Updating Dht record", addrs = addrs
  d.dhtRecord = SignedPeerRecord
    .init(d.key, PeerRecord.init(d.peerId, @addrs))
    .expect("Should construct signed record").some

  if not d.protocol.isNil:
    d.protocol.updateRecord(d.dhtRecord).expect("Should update SPR")

proc start*(d: Dht) {.async.} =
  d.protocol.open()
  await d.protocol.start()

proc stop*(d: Dht) {.async.} =
  await d.protocol.closeWait()

proc new*(
    T: type Dht,
    key: PrivateKey,
    bindIp = IPv4_any(),
    bindPort = 0.Port,
    announceAddrs: openArray[MultiAddress],
    bootstrapNodes: openArray[SignedPeerRecord] = [],
    store: Datastore = SQLiteDatastore.new(Memory).expect("Should not fail!"),
): Dht =
  var self = Dht(key: key, peerId: PeerId.init(key).expect("Should construct PeerId"))

  self.updateAnnounceRecord(announceAddrs)

  # --------------------------------------------------------------------------
  # FIXME disable IP limits temporarily so we can run our workshop. Re-enable
  #   and figure out proper solution.
  let discoveryConfig = DiscoveryConfig(
    tableIpLimits: TableIpLimits(tableIpLimit: high(uint), bucketIpLimit: high(uint)),
    bitsPerHop: DefaultBitsPerHop,
  )
  # --------------------------------------------------------------------------

  self.protocol = newProtocol(
    key,
    bindIp = bindIp,
    bindPort = bindPort,
    record = self.providerRecord.get,
    bootstrapRecords = bootstrapNodes,
    rng = Rng.instance(),
    providers = ProvidersManager.new(store),
    config = discoveryConfig,
  )

  self
