import std/os
import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import pkg/datastore
import pkg/datastore/typedds
import pkg/metrics

import ./config
import ./logging
import ./metrics
import ./list

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
    config*: CrawlerConfig
    todoList*: List
    okNodes*: List
    nokNodes*: List

proc createDatastore(app: Application): ?!TypedDatastore =
  without store =? LevelDbDatastore.new(app.config.dataDir), err:
    error "Failed to create datastore"
    return failure(err)
  return success(TypedDatastore.init(store))

proc initializeLists(app: Application): Future[?!void] {.async.} =
  without store =? app.createDatastore(), err:
    return failure(err)

  # We can't extract this into a function because gauges cannot be passed as argument.
  # The use of global state in nim-metrics is not pleasant.
  proc onTodoMetric(value: int64) =
    todoNodesGauge.set(value)

  proc onOkMetric(value: int64) =
    okNodesGauge.set(value)

  proc onNokMetric(value: int64) =
    nokNodesGauge.set(value)

  app.todoList = List.new("todo", store, onTodoMetric)
  app.okNodes = List.new("ok", store, onOkMetric)
  app.nokNodes = List.new("nok", store, onNokMetric)

  if err =? (await app.todoList.load()).errorOption:
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
  return success()

proc stop*(app: Application) =
  app.status = ApplicationStatus.Stopping

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
