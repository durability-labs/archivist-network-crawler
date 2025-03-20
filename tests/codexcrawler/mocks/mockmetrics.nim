import ../../../codexcrawler/services/metrics

type MockMetrics* = ref object of Metrics
  todo*: int
  ok*: int
  nok*: int
  requests*: int
  slots*: int
  totalSize*: int

method setTodoNodes*(m: MockMetrics, value: int) =
  m.todo = value

method setOkNodes*(m: MockMetrics, value: int) =
  m.ok = value

method setNokNodes*(m: MockMetrics, value: int) =
  m.nok = value

method setRequests*(m: MockMetrics, value: int) =
  m.requests = value

method setRequestSlots*(m: MockMetrics, value: int) =
  m.slots = value

method setTotalSize*(m: MockMetrics, value: int) =
  m.totalSize = value

proc createMockMetrics*(): MockMetrics =
  MockMetrics()
