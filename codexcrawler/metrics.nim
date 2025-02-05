import pkg/chronicles
import pkg/metrics
import pkg/metrics/chronos_httpserver

proc setupMetrics*(metricsAddress: IpAddress, metricsPort: Port) =
  let metricsAddress = metricsAddress
  notice "Starting metrics HTTP server",
    url = "http://" & $metricsAddress & ":" & $metricsPort & "/metrics"
  try:
    startMetricsHttpServer($metricsAddress, metricsPort)
  except CatchableError as exc:
    raiseAssert exc.msg
  except Exception as exc:
    raiseAssert exc.msg # TODO fix metrics
