import pkg/chronicles
import pkg/chronos
import pkg/questionable/results

import ./nodestore
import ../services/dht
import ../services/clock
import ../component
import ../state
import ../types
import ../utils/asyncdataevent

logScope:
  topics = "timetracker"

type TimeTracker* = ref object of Component
  state: State
  nodestore: NodeStore
  dht: Dht
  clock: Clock

proc checkForExpiredNodes(t: TimeTracker): Future[?!void] {.async: (raises: []).} =
  let expiry = t.clock.now() - (t.state.config.expiryDelayMins * 60).uint64

  var expired = newSeq[Nid]()
  proc checkNode(item: NodeEntry): Future[?!void] {.async: (raises: []), gcsafe.} =
    if item.lastVisit < expiry:
      expired.add(item.id)
    return success()

  ?await t.nodestore.iterateAll(checkNode)

  if expired.len > 0:
    trace "Found expired nodes", expired = expired.len
    ?await t.state.events.nodesExpired.fire(expired)

  return success()

proc raiseRoutingTableNodes(t: TimeTracker): Future[?!void] {.async: (raises: []).} =
  let nids = t.dht.getRoutingTableNodeIds()
  trace "Raising routing table nodes", nodes = nids.len

  if err =? (await t.state.events.nodesFound.fire(nids)).errorOption:
    return failure(err)
  return success()

method start*(t: TimeTracker): Future[?!void] {.async.} =
  info "Starting..."

  proc onCheckExpiry(): Future[?!void] {.async: (raises: []), gcsafe.} =
    await t.checkForExpiredNodes()

  proc onRoutingTable(): Future[?!void] {.async: (raises: []), gcsafe.} =
    await t.raiseRoutingTableNodes()

  await t.state.whileRunning(onCheckExpiry, t.state.config.checkDelayMins.minutes)
  await t.state.whileRunning(onRoutingTable, 30.minutes)
  return success()

method stop*(t: TimeTracker): Future[?!void] {.async.} =
  return success()

proc new*(
    T: type TimeTracker, state: State, nodestore: NodeStore, dht: Dht, clock: Clock
): TimeTracker =
  TimeTracker(state: state, nodestore: nodestore, dht: dht, clock: clock)
