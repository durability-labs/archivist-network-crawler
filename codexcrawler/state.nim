import pkg/chronos
import pkg/questionable/results

import ./config
import ./utils/asyncdataevent
import ./types

type
  OnStep = proc(): Future[?!void] {.async: (raises: []), gcsafe.}

  DhtNodeCheckEventData* = object
    id*: Nid
    isOk*: bool

  Events* = ref object
    nodesFound*: AsyncDataEvent[seq[Nid]]
    newNodesDiscovered*: AsyncDataEvent[seq[Nid]]
    dhtNodeCheck*: AsyncDataEvent[DhtNodeCheckEventData]
    nodesExpired*: AsyncDataEvent[seq[Nid]]

  State* = ref object
    config*: Config
    events*: Events

proc whileRunning*(this: State, step: OnStep, delay: Duration) =
  discard
  #todo: while status == running, step(), asyncsleep duration
