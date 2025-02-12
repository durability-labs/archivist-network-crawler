import ../../../codexcrawler/services/metrics

type MockMetrics* = ref object of Metrics
  todo*: int
  ok*: int
  nok*: int

method setTodoNodes*(m: MockMetrics, value: int) =
  m.todo = value

method setOkNodes*(m: MockMetrics, value: int) =
  m.ok = value

method setNokNodes*(m: MockMetrics, value: int) =
  m.nok = value

proc createMockMetrics*(): MockMetrics =
  MockMetrics()
