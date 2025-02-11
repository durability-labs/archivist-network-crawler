import ../../codexcrawler/state
import ../../codexcrawler/utils/asyncdataevent
import ../../codexcrawler/types
import ../../codexcrawler/config

type
  MockState* = ref object of State
    # config*: Config
    # events*: Events


proc createMockState*(): MockState =
  MockState(
    config: Config(),
    events: Events(
      nodesFound: newAsyncDataEvent[seq[Nid]](),
      newNodesDiscovered: newAsyncDataEvent[seq[Nid]](),
      dhtNodeCheck: newAsyncDataEvent[DhtNodeCheckEventData](),
      nodesExpired: newAsyncDataEvent[seq[Nid]](),
    ),
  )

proc cleanupMock*(this: MockState) =
  discard
