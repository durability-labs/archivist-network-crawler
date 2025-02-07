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
import ./crawler

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
    todoNodes*: List
    okNodes*: List
    nokNodes*: List
    dht*: Dht
    crawler*: Crawler

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

proc initializeDht(app: Application): Future[?!void] {.async.} =
  without dhtStore =? app.createDatastore(app.config.dataDir / "dht"), err:
    return failure(err)
  let keyPath = app.config.dataDir / "privatekey"
  without privateKey =? setupKey(keyPath), err:
    return failure(err)

  var listenAddresses = newSeq[MultiAddress]()
  # TODO: when p2p connections are supported:
  # let aaa = MultiAddress.init("/ip4/" & app.config.publicIp & "/tcp/53678").expect("Should init multiaddress")
  # listenAddresses.add(aaa)

  var discAddresses = newSeq[MultiAddress]()
  let bbb = MultiAddress
    .init("/ip4/" & app.config.publicIp & "/udp/" & $app.config.discPort)
    .expect("Should init multiaddress")
  discAddresses.add(bbb)

  app.dht = Dht.new(
    privateKey,
    bindPort = app.config.discPort,
    announceAddrs = listenAddresses,
    bootstrapNodes = app.config.bootNodes,
    store = dhtStore,
  )

  app.dht.updateAnnounceRecord(listenAddresses)
  app.dht.updateDhtRecord(discAddresses)

  await app.dht.start()

  return success()

proc initializeCrawler(app: Application): Future[?!void] {.async.} =
  app.crawler = Crawler.new(app.dht, app.todoNodes, app.okNodes, app.nokNodes)
  return await app.crawler.start()

proc initializeApp(app: Application): Future[?!void] {.async.} =
  if err =? (await app.initializeLists()).errorOption:
    error "Failed to initialize lists", err = err.msg
    return failure(err)

  if err =? (await app.initializeDht()).errorOption:
    error "Failed to initialize DHT", err = err.msg
    return failure(err)

  if err =? (await app.initializeCrawler()).errorOption:
    error "Failed to initialize crawler", err = err.msg
    return failure(err)

  return success()

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

  while app.status == ApplicationStatus.Running:
    try:
      chronos.poll()
    except Exception as exc:
      error "Unhandled exception", msg = exc.msg
      quit QuitFailure
  notice "Application closed"
