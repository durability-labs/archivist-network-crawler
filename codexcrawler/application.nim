import std/os
import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import pkg/metrics

import ./config
import ./utils/logging
import ./utils/asyncdataevent
import ./installer
import ./state
import ./component
import ./types

type Application* = ref object
  state: State

proc initializeApp(app: Application, config: Config): Future[?!void] {.async.} =
  let state = State(
    status: ApplicationStatus.Running,
    config: config,
    events: Events(
      nodesFound: newAsyncDataEvent[seq[Nid]](),
      newNodesDiscovered: newAsyncDataEvent[seq[Nid]](),
      dhtNodeCheck: newAsyncDataEvent[DhtNodeCheckEventData](),
      nodesExpired: newAsyncDataEvent[seq[Nid]](),
    ),
  )

  without components =? (await createComponents(state)), err:
    error "Failed to create componenents", err = err.msg
    return failure(err)

  for c in components:
    if err =? (await c.start()).errorOption:
      error "Failed to start component", err = err.msg

  return success()

proc stop*(app: Application) =
  app.state.status = ApplicationStatus.Stopping

proc run*(app: Application) =
  let config = parseConfig()
  info "Loaded configuration", config = $config

  # Configure loglevel
  updateLogLevel(config.logLevel)

  # Ensure datadir path exists:
  if not existsDir(config.dataDir):
    createDir(config.dataDir)

  info "Metrics endpoint initialized"

  info "Starting application"
  app.state.status = ApplicationStatus.Running
  if err =? (waitFor app.initializeApp(config)).errorOption:
    app.state.status = ApplicationStatus.Stopping
    error "Failed to start application", err = err.msg
    return

  while app.state.status == ApplicationStatus.Running:
    try:
      chronos.poll()
    except Exception as exc:
      error "Unhandled exception", msg = exc.msg
      quit QuitFailure
  notice "Application closed"
