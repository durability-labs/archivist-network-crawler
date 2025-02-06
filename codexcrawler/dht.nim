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

proc getNode*(d: Dht, nodeId: NodeId): ?!Node =
  let node = d.protocol.getNode(nodeId)
  if node.isSome():
    return success(node.get())
  return failure("Node not found for id: " & $nodeId)

proc hacky*(d: Dht, nodeId: NodeId) {.async.} =
  let node = await d.protocol.resolve(nodeId)
  if node.isSome():
    info "that worked"
  else:
    info "that didn't work"
    
proc getRoutingTableNodeIds*(d: Dht): Future[seq[NodeId]] {.async.} =
  var ids = newSeq[NodeId]()
  for bucket in d.protocol.routingTable.buckets:
    for node in bucket.nodes:
      warn "node seen", node = $node.id, seen = $node.seen
      ids.add(node.id)

      # await d.hacky(node.id)
      await sleepAsync(1)
  return ids

proc getDistances(): seq[uint16] =
  var d = newSeq[uint16]()
  for i in 0..10:
    d.add(i.uint16)
  return d

proc getNeighbors*(d: Dht, target: NodeId): Future[?!seq[Node]] {.async.} =
  without node =? d.getNode(target), err:
    return failure(err)

  let distances = getDistances()
  let response = await d.protocol.findNode(node, distances)

  if response.isOk():
    let nodes = response.get()
    if nodes.len > 0:
      return success(nodes)

  # Both returning 0 nodes and a failure result are treated as failure of getNeighbors
  return failure("No nodes returned")

proc findPeer*(d: Dht, peerId: PeerId): Future[?PeerRecord] {.async.} =
  trace "protocol.resolve..."
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

  # This disables IP limits:
  let discoveryConfig = DiscoveryConfig(
    tableIpLimits: TableIpLimits(tableIpLimit: high(uint), bucketIpLimit: high(uint)),
    bitsPerHop: DefaultBitsPerHop,
  )

  trace "Creating DHT protocol", ip = $bindIp, port = $bindPort
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
