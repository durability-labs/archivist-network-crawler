import pkg/chronos
import pkg/chronicles
import pkg/datastore
import pkg/datastore/typedds
import pkg/questionable
import pkg/questionable/results

import std/sets

import ../state
import ../types
import ../component
import ../utils/asyncdataevent

logScope:
  topics = "todolist"

type TodoList* = ref object of Component
  nids: seq[Nid]
  state: State
  subNew: AsyncDataEventSubscription
  subExp: AsyncDataEventSubscription
  emptySignal: ?Future[void]

proc addNodes(t: TodoList, nids: seq[Nid]) =
  for nid in nids:
    t.nids.add(nid)

  if s =? t.emptySignal:
    trace "Nodes added, resuming...", nodes = nids.len
    s.complete()
    t.emptySignal = Future[void].none

method pop*(t: TodoList): Future[?!Nid] {.async: (raises: []), base.} =
  if t.nids.len < 1:
    trace "List is empty. Waiting for new items..."
    let signal = newFuture[void]("list.emptySignal")
    t.emptySignal = some(signal)
    try:
      await signal.wait(InfiniteDuration)
    except CatchableError as exc:
      return failure(exc.msg)
    if t.nids.len < 1:
      return failure("TodoList is empty.")

  let item = t.nids[0]
  t.nids.del(0)

  return success(item)

method start*(t: TodoList): Future[?!void] {.async.} =
  info "Starting TodoList..."

  proc onNewNodes(nids: seq[Nid]): Future[?!void] {.async.} =
    t.addNodes(nids)
    return success()

  t.subNew = t.state.events.newNodesDiscovered.subscribe(onNewNodes)
  t.subExp = t.state.events.nodesExpired.subscribe(onNewNodes)
  return success()

method stop*(t: TodoList): Future[?!void] {.async.} =
  await t.state.events.newNodesDiscovered.unsubscribe(t.subNew)
  await t.state.events.nodesExpired.unsubscribe(t.subExp)
  return success()

proc new*(_: type TodoList, state: State): TodoList =
  TodoList(nids: newSeq[Nid](), state: state, emptySignal: Future[void].none)

proc createTodoList*(state: State): TodoList =
  TodoList.new(state)
