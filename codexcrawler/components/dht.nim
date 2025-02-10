import std/os
import std/net
import pkg/chronicles
import pkg/chronos
import pkg/libp2p
import pkg/questionable
import pkg/questionable/results
import pkg/codexdht/discv5/[routing_table, protocol as discv5]
from pkg/nimcrypto import keccak256

import ../utils/keyutils
import ../utils/datastoreutils
import ../utils/rng
import ../component
import ../config
import ../state

export discv5

logScope:
  topics = "dht"

type Dht* = ref object of Component
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

proc getRoutingTableNodeIds*(d: Dht): seq[NodeId] =
  var ids = newSeq[NodeId]()
  for bucket in d.protocol.routingTable.buckets:
    for node in bucket.nodes:
      ids.add(node.id)
  return ids

proc getNeighbors*(d: Dht, target: NodeId): Future[?!seq[Node]] {.async.} =
  without node =? d.getNode(target), err:
    return failure(err)

  let distances = @[256.uint16]
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

method start*(d: Dht, state: State): Future[?!void] {.async.} =
  d.protocol.open()
  await d.protocol.start()
  return success()

method stop*(d: Dht): Future[?!void] {.async.} =
  await d.protocol.closeWait()
  return success()

proc new(
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

proc createDht*(config: Config): Future[?!Dht] {.async.} =
  without dhtStore =? createDatastore(config.dataDir / "dht"), err:
    return failure(err)
  let keyPath = config.dataDir / "privatekey"
  without privateKey =? setupKey(keyPath), err:
    return failure(err)

  var listenAddresses = newSeq[MultiAddress]()
  # TODO: when p2p connections are supported:
  # let aaa = MultiAddress.init("/ip4/" & config.publicIp & "/tcp/53678").expect("Should init multiaddress")
  # listenAddresses.add(aaa)

  var discAddresses = newSeq[MultiAddress]()
  let bbb = MultiAddress
    .init("/ip4/" & config.publicIp & "/udp/" & $config.discPort)
    .expect("Should init multiaddress")
  discAddresses.add(bbb)

  let dht = Dht.new(
    privateKey,
    bindPort = config.discPort,
    announceAddrs = listenAddresses,
    bootstrapNodes = config.bootNodes,
    store = dhtStore,
  )

  dht.updateAnnounceRecord(listenAddresses)
  dht.updateDhtRecord(discAddresses)

  return success(dht)
