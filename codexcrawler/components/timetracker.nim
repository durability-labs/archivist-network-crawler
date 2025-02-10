import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ./dht
import ../list
import ../config
import ../component
import ../state

logScope:
  topics = "timetracker"

type TimeTracker* = ref object of Component
  config: Config
  todoNodes: List
  okNodes: List
  nokNodes: List
  workerDelay: int

# # proc processList(t: TimeTracker, list: List, expiry: uint64) {.async.} =
# #   var toMove = newSeq[NodeEntry]()
# #   proc onItem(item: NodeEntry) =
# #     if item.lastVisit < expiry:
# #       toMove.add(item)

# #   await list.iterateAll(onItem)

# #   if toMove.len > 0:
# #     trace "expired node, moving to todo", nodes = $toMove.len

# #   for item in toMove:
# #     if err =? (await t.todoNodes.add(item)).errorOption:
# #       error "Failed to add expired node to todo list", err = err.msg
# #       return
# #     if err =? (await list.remove(item)).errorOption:
# #       error "Failed to remove expired node to source list", err = err.msg

# proc step(t: TimeTracker) {.async.} =
#   let expiry = (Moment.now().epochSeconds - (t.config.revisitDelayMins * 60)).uint64
#   await t.processList(t.okNodes, expiry)
#   await t.processList(t.nokNodes, expiry)

proc worker(t: TimeTracker) {.async.} =
  try:
    while true:
      # await t.step()
      await sleepAsync(t.workerDelay.minutes)
  except Exception as exc:
    error "Exception in timetracker worker", msg = exc.msg
    quit QuitFailure

method start*(t: TimeTracker, state: State): Future[?!void] {.async.} =
  info "Starting timetracker...", revisitDelayMins = $t.workerDelay
  asyncSpawn t.worker()
  return success()

method stop*(t: TimeTracker): Future[?!void] {.async.} =
  return success()

proc new*(
    T: type TimeTracker,
    # todoNodes: List,
    # okNodes: List,
    # nokNodes: List,
    config: Config,
): TimeTracker =
  var delay = config.revisitDelayMins div 10
  if delay < 1:
    delay = 1

  TimeTracker(
    # todoNodes: todoNodes,
    # okNodes: okNodes,
    # nokNodes: nokNodes,
    config: config,
    workerDelay: delay,
  )
