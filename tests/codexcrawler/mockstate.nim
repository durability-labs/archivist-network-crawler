import pkg/asynctest/chronos/unittest
import ../../codexcrawler/state
import ../../codexcrawler/utils/asyncdataevent
import ../../codexcrawler/types
import ../../codexcrawler/config

type MockState* = ref object of State
  stepper*: OnStep

proc checkAllUnsubscribed*(s: MockState) =
  check:
    s.events.nodesFound.listeners == 0
    s.events.newNodesDiscovered.listeners == 0
    s.events.dhtNodeCheck.listeners == 0
    s.events.nodesExpired.listeners == 0

method whileRunning*(s: MockState, step: OnStep, delay: Duration) {.async.} =
  s.stepper = step

proc createMockState*(): MockState =
  MockState(
    status: ApplicationStatus.Running,
    config: Config(),
    events: Events(
      nodesFound: newAsyncDataEvent[seq[Nid]](),
      newNodesDiscovered: newAsyncDataEvent[seq[Nid]](),
      dhtNodeCheck: newAsyncDataEvent[DhtNodeCheckEventData](),
      nodesExpired: newAsyncDataEvent[seq[Nid]](),
    ),
  )
