import pkg/chronicles
import pkg/metrics
import pkg/metrics/chronos_httpserver

declareGauge(todoNodesGauge, "DHT nodes to be visited")
declareGauge(okNodesGauge, "DHT nodes successfully contacted")
declareGauge(nokNodesGauge, "DHT nodes failed to contact")

type
  OnUpdateMetric = proc(value: int64): void {.gcsafe, raises: [].}

  Metrics* = ref object
    todoNodes: OnUpdateMetric
    okNodes: OnUpdateMetric
    nokNodes: OnUpdateMetric

proc startServer(metricsAddress: IpAddress, metricsPort: Port) =
  let metricsAddress = metricsAddress
  notice "Starting metrics HTTP server",
    url = "http://" & $metricsAddress & ":" & $metricsPort & "/metrics"
  try:
    startMetricsHttpServer($metricsAddress, metricsPort)
  except CatchableError as exc:
    raiseAssert exc.msg
  except Exception as exc:
    raiseAssert exc.msg # TODO fix metrics

method setTodoNodes*(m: Metrics, value: int) {.base.} =
  m.todoNodes(value.int64)

method setOkNodes*(m: Metrics, value: int) {.base.} =
  m.okNodes(value.int64)

method setNokNodes*(m: Metrics, value: int) {.base.} =
  m.nokNodes(value.int64)

proc createMetrics*(metricsAddress: IpAddress, metricsPort: Port): Metrics =
  startServer(metricsAddress, metricsPort)

  # We can't extract this into a function because gauges cannot be passed as argument.
  # The use of global state in nim-metrics is not pleasant.
  proc onTodo(value: int64) =
    todoNodesGauge.set(value)

  proc onOk(value: int64) =
    okNodesGauge.set(value)

  proc onNok(value: int64) =
    nokNodesGauge.set(value)
  
  return Metrics(
    todoNodes: onTodo,
    okNodes: onOk,
    nokNodes: onNok
  )
