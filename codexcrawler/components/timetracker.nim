import pkg/chronicles
import pkg/chronos
import pkg/questionable/results

import ./nodestore
import ../component
import ../state
import ../types
import ../utils/asyncdataevent

logScope:
  topics = "timetracker"

type TimeTracker* = ref object of Component
  state: State
  nodestore: NodeStore

proc step(t: TimeTracker): Future[?!void] {.async: (raises: []).} =
  let expiry =
    (Moment.now().epochSeconds - (t.state.config.revisitDelayMins * 60)).uint64

  var expired = newSeq[Nid]()
  proc checkNode(item: NodeEntry): Future[?!void] {.async: (raises: []), gcsafe.} =
    if item.lastVisit < expiry:
      expired.add(item.id)
    return success()

  ?await t.nodestore.iterateAll(checkNode)
  ?await t.state.events.nodesExpired.fire(expired)
  return success()

method start*(t: TimeTracker): Future[?!void] {.async.} =
  info "Starting timetracker..."

  proc onStep(): Future[?!void] {.async: (raises: []), gcsafe.} =
    await t.step()

  var delay = t.state.config.revisitDelayMins div 100
  if delay < 1:
    delay = 1

  await t.state.whileRunning(onStep, delay.minutes)
  return success()

method stop*(t: TimeTracker): Future[?!void] {.async.} =
  return success()

proc new*(T: type TimeTracker, state: State, nodestore: NodeStore): TimeTracker =
  TimeTracker(state: state, nodestore: nodestore)
