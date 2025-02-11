import pkg/asynctest/chronos/unittest
import ../../codexcrawler/state
import ../../codexcrawler/utils/asyncdataevent
import ../../codexcrawler/types
import ../../codexcrawler/config

type MockState* = ref object of State

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

proc checkAllUnsubscribed*(this: MockState) =
  check:
    this.events.nodesFound.listeners == 0
    this.events.newNodesDiscovered.listeners == 0
    this.events.dhtNodeCheck.listeners == 0
    this.events.nodesExpired.listeners == 0
