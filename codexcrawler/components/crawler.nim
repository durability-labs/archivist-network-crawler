import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ../services/dht
import ./todolist
import ../config
import ../types
import ../component
import ../state
import ../utils/asyncdataevent

logScope:
  topics = "crawler"

type Crawler* = ref object of Component
  state: State
  dht: Dht
  todo: TodoList

proc raiseCheckEvent(c: Crawler, nid: Nid, success: bool): Future[?!void] {.async: (raises: []).} =
  let event = DhtNodeCheckEventData(
    id: nid,
    isOk: success
  )
  if err =? (await c.state.events.dhtNodeCheck.fire(event)).errorOption:
    return failure(err)
  return success()

proc step(c: Crawler): Future[?!void] {.async: (raises: []).} =
  without nid =? (await c.todo.pop()), err:
    return failure(err)

  without response =? await c.dht.getNeighbors(nid), err:
    return failure(err)

  if err =? (await c.raiseCheckEvent(nid, response.isResponsive)).errorOption:
    return failure(err)

  if err =? (await c.state.events.nodesFound.fire(response.nodeIds)).errorOption:
    return failure(err)

  return success()

method start*(c: Crawler): Future[?!void] {.async.} =
  info "Starting crawler..."

  proc onStep(): Future[?!void] {.async: (raises: []), gcsafe.} =
    await c.step()
  await c.state.whileRunning(onStep, c.state.config.stepDelayMs.milliseconds)

  return success()

method stop*(c: Crawler): Future[?!void] {.async.} =
  return success()

proc new*(
    T: type Crawler,
    state: State,
    dht: Dht,
    todo: TodoList
): Crawler =
  Crawler(
    state: state,
    dht: dht,
    todo: todo
  )
