import std/os
import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import pkg/metrics

import ./config
import ./utils/logging
import ./metrics
import ./list
import ./utils/datastoreutils
import ./utils/asyncdataevent
import ./installer
import ./state
import ./component
import ./types

declareGauge(todoNodesGauge, "DHT nodes to be visited")
declareGauge(okNodesGauge, "DHT nodes successfully contacted")
declareGauge(nokNodesGauge, "DHT nodes failed to contact")

type
  ApplicationStatus* {.pure.} = enum
    Stopped
    Stopping
    Running

  Application* = ref object
    status: ApplicationStatus
    config*: Config
    todoNodes*: List
    okNodes*: List
    nokNodes*: List

proc initializeLists(app: Application): Future[?!void] {.async.} =
  without store =? createTypedDatastore(app.config.dataDir / "lists"), err:
    return failure(err)

  # We can't extract this into a function because gauges cannot be passed as argument.
  # The use of global state in nim-metrics is not pleasant.
  proc onTodoMetric(value: int64) =
    todoNodesGauge.set(value)

  proc onOkMetric(value: int64) =
    okNodesGauge.set(value)

  proc onNokMetric(value: int64) =
    nokNodesGauge.set(value)

  app.todoNodes = List.new("todo", store, onTodoMetric)
  app.okNodes = List.new("ok", store, onOkMetric)
  app.nokNodes = List.new("nok", store, onNokMetric)

  if err =? (await app.todoNodes.load()).errorOption:
    return failure(err)
  if err =? (await app.okNodes.load()).errorOption:
    return failure(err)
  if err =? (await app.nokNodes.load()).errorOption:
    return failure(err)

  return success()

proc initializeApp(app: Application): Future[?!void] {.async.} =
  if err =? (await app.initializeLists()).errorOption:
    error "Failed to initialize lists", err = err.msg
    return failure(err)

  # if err =? (await app.initializeDht()).errorOption:
  #   error "Failed to initialize DHT", err = err.msg
  #   return failure(err)

  # if err =? (await app.initializeCrawler()).errorOption:
  #   error "Failed to initialize crawler", err = err.msg
  #   return failure(err)

  # if err =? (await app.initializeTimeTracker()).errorOption:
  #   error "Failed to initialize timetracker", err = err.msg
  #   return failure(err)

  without components =? (await createComponents(app.config)), err:
    error "Failed to create componenents", err = err.msg
    return failure(err)

  # todo move this
  let state = State(
    config: app.config,
    events: Events(
      nodesFound: newAsyncDataEvent[seq[Nid]](),
      newNodesDiscovered: newAsyncDataEvent[seq[Nid]](),
      dhtNodeCheck: newAsyncDataEvent[DhtNodeCheckEventData](),
      nodesExpired: newAsyncDataEvent[seq[Nid]](),
    ),
  )

  for c in components:
    if err =? (await c.start(state)).errorOption:
      error "Failed to start component", err = err.msg

  # test raise newnodes
  let nodes: seq[Nid] = newSeq[Nid]()
  if err =? (await state.events.nodesFound.fire(nodes)).errorOption:
    return failure(err)

  return success()

proc stop*(app: Application) =
  app.status = ApplicationStatus.Stopping
  # waitFor app.dht.stop()

proc run*(app: Application) =
  app.config = parseConfig()
  info "Loaded configuration", config = app.config

  # Configure loglevel
  updateLogLevel(app.config.logLevel)

  # Ensure datadir path exists:
  if not existsDir(app.config.dataDir):
    createDir(app.config.dataDir)

  setupMetrics(app.config.metricsAddress, app.config.metricsPort)
  info "Metrics endpoint initialized"

  info "Starting application"
  app.status = ApplicationStatus.Running
  if err =? (waitFor app.initializeApp()).errorOption:
    app.status = ApplicationStatus.Stopping
    error "Failed to start application", err = err.msg
    return

  while app.status == ApplicationStatus.Running:
    try:
      chronos.poll()
    except Exception as exc:
      error "Unhandled exception", msg = exc.msg
      quit QuitFailure
  notice "Application closed"
