import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ./dht
import ./list
import ./nodeentry
import ./config

import std/sequtils

logScope:
  topics = "crawler"

type Crawler* = ref object
  dht: Dht
  config: CrawlerConfig
  todoNodes: List
  okNodes: List
  nokNodes: List

# This is not going to stay this way.
proc isNew(c: Crawler, node: Node): bool =
  not c.todoNodes.contains(node.id) and not c.okNodes.contains(node.id) and
    not c.nokNodes.contains(node.id)

proc handleNodeNotOk(c: Crawler, target: NodeEntry) {.async.} =
  if err =? (await c.nokNodes.add(target)).errorOption:
    error "Failed to add not-OK-node to list", err = err.msg

proc handleNodeOk(c: Crawler, target: NodeEntry) {.async.} =
  if err =? (await c.okNodes.add(target)).errorOption:
    error "Failed to add OK-node to list", err = err.msg

proc addNewTodoNode(c: Crawler, nodeId: NodeId): Future[?!void] {.async.} =
  let entry = NodeEntry(id: nodeId, lastVisit: 0)
  return await c.todoNodes.add(entry)

proc addNewTodoNodes(c: Crawler, newNodes: seq[Node]) {.async.} =
  for node in newNodes:
    if err =? (await c.addNewTodoNode(node.id)).errorOption:
      error "Failed to add todo-node to list", err = err.msg

proc step(c: Crawler) {.async.} =
  logScope:
    todo = $c.todoNodes.len
    ok = $c.okNodes.len
    nok = $c.nokNodes.len

  without var target =? (await c.todoNodes.pop()), err:
    error "Failed to get todo node", err = err.msg

  target.lastVisit = Moment.now().epochSeconds.uint64

  without receivedNodes =? (await c.dht.getNeighbors(target.id)), err:
    await c.handleNodeNotOk(target)
    return

  let newNodes = receivedNodes.filterIt(isNew(c, it))
  if newNodes.len > 0:
    trace "Discovered new nodes", newNodes = newNodes.len

  await c.handleNodeOk(target)
  await c.addNewTodoNodes(newNodes)

  # Don't log the status every loop:
  if (c.todoNodes.len mod 10) == 0:
    trace "Status"

proc worker(c: Crawler) {.async.} =
  try:
    while true:
      await c.step()
      await sleepAsync(c.config.stepDelayMs.millis)
  except Exception as exc:
    error "Exception in crawler worker", msg = exc.msg
    quit QuitFailure

proc start*(c: Crawler): Future[?!void] {.async.} =
  if c.todoNodes.len < 1:
    let nodeIds = c.dht.getRoutingTableNodeIds()
    info "Loading routing-table nodes to todo-list...", nodes = nodeIds.len
    for id in nodeIds:
      if err =? (await c.addNewTodoNode(id)).errorOption:
        error "Failed to add routing-table node to todo-list", err = err.msg
        return failure(err)

  info "Starting crawler...", stepDelayMs = $c.config.stepDelayMs
  asyncSpawn c.worker()
  return success()

proc new*(
    T: type Crawler,
    dht: Dht,
    todoNodes: List,
    okNodes: List,
    nokNodes: List,
    config: CrawlerConfig,
): Crawler =
  Crawler(
    dht: dht, todoNodes: todoNodes, okNodes: okNodes, nokNodes: nokNodes, config: config
  )
