import pkg/chronos
import pkg/chronicles
import pkg/questionable/results

import ./config
import ./utils/asyncdataevent
import ./types

logScope:
  topics = "state"

type
  OnStep* = proc(): Future[?!void] {.async: (raises: []), gcsafe.}

  DhtNodeCheckEventData* = object
    id*: Nid
    isOk*: bool

  Events* = ref object
    nodesFound*: AsyncDataEvent[seq[Nid]]
    newNodesDiscovered*: AsyncDataEvent[seq[Nid]]
    dhtNodeCheck*: AsyncDataEvent[DhtNodeCheckEventData]
    nodesExpired*: AsyncDataEvent[seq[Nid]]

  ApplicationStatus* {.pure.} = enum
    Stopped
    Stopping
    Running

  State* = ref object of RootObj
    status*: ApplicationStatus
    config*: Config
    events*: Events

method whileRunning*(s: State, step: OnStep, delay: Duration) {.async, base.} =
  proc worker(): Future[void] {.async.} =
    while s.status == ApplicationStatus.Running:
      if err =? (await step()).errorOption:
        error "Failure-result caught in main loop. Stopping...", err = err.msg
        s.status = ApplicationStatus.Stopping
      await sleepAsync(delay)

  # todo this needs a delay because starts are still being called.
  asyncSpawn worker()
