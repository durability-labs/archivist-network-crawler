import std/os
import std/sequtils
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
import ./dht
import ./keyutils

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
    dht*: Dht

proc createDatastore(app: Application, path: string): ?!Datastore =
  without store =? LevelDbDatastore.new(path), err:
    error "Failed to create datastore"
    return failure(err)
  return success(Datastore(store))

proc createTypedDatastore(app: Application, path: string): ?!TypedDatastore =
  without store =? app.createDatastore(path), err:
    return failure(err)
  return success(TypedDatastore.init(store))

proc initializeLists(app: Application): Future[?!void] {.async.} =
  without store =? app.createTypedDatastore(app.config.dataDir / "lists"), err:
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

proc initializeDht(app: Application): Future[?!void] {.async.} =
  without dhtStore =? app.createDatastore(app.config.dataDir / "dht"), err:
    return failure(err)
  let keyPath = app.config.dataDir / "privatekey"
  without privateKey =? setupKey(keyPath), err:
    return failure(err)

  var announceAddresses = newSeq[MultiAddress]()
  let aaa = MultiAddress.init("/ip4/172.21.64.1/udp/8090").expect("Should init multiaddress")
  # /ip4/45.82.185.194/udp/8090
  # /ip4/172.21.64.1/udp/8090
  announceAddresses.add(aaa)

  app.dht = Dht.new(
    privateKey,
    bindPort = app.config.discPort,
    announceAddrs = announceAddresses,
    bootstrapNodes = app.config.bootNodes,
    store = dhtStore,
  )

  await app.dht.start()
  return success()

proc initializeApp(app: Application): Future[?!void] {.async.} =
  if err =? (await app.initializeLists()).errorOption:
    error "Failed to initialize lists", err = err.msg
    return failure(err)

  if err =? (await app.initializeDht()).errorOption:
    error "Failed to initialize DHT", err = err.msg
    return failure(err)

  return success()

proc hackyCrawl(app: Application) {.async.} =
  info "starting hacky crawl..."
  await sleepAsync(3000)

  var nodeIds = await app.dht.getRoutingTableNodeIds()
  trace "starting with routing table nodes", nodes = nodeIds.len

  while app.status == ApplicationStatus.Running:
    let nodeId = nodeIds[0]
    nodeIds.delete(0)

    without newNodes =? (await app.dht.getNeighbors(nodeId)), err:
      error "getneighbors failed", err = err.msg
      
    trace "adding new nodes", len = newNodes.len
    for id in newNodes.mapIt(it.id):
      nodeIds.add(id)
    await sleepAsync(1000)


proc stop*(app: Application) =
  app.status = ApplicationStatus.Stopping
  waitFor app.dht.stop()

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

  asyncSpawn app.hackyCrawl()

  while app.status == ApplicationStatus.Running:
    try:
      chronos.poll()
    except Exception as exc:
      error "Unhandled exception", msg = exc.msg
      quit QuitFailure
  notice "Application closed"
