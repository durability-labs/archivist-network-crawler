import std/os
import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ./config
import ./logging
import ./metrics

import ./main

type
  ApplicationStatus* {.pure.} = enum
    Stopped
    Stopping
    Running

  Application* = ref object
    status: ApplicationStatus

proc run*(app: Application) =
  let config = parseConfig()
  info "Loaded configuration", config

  # Configure loglevel
  updateLogLevel(config.logLevel)

  # Ensure datadir path exists:
  if not existsDir(config.dataDir):
    createDir(config.dataDir)

  setupMetrics(config.metricsAddress, config.metricsPort)
  info "Metrics endpoint initialized"

  info "Starting application"
  app.status = ApplicationStatus.Running
  if err =? (waitFor startApplication(config)).errorOption:
    app.status = ApplicationStatus.Stopping
    error "Failed to start application", err = err.msg

  while app.status == ApplicationStatus.Running:
    try:
      chronos.poll()
    except Exception as exc:
      error "Unhandled exception", msg = exc.msg
      quit QuitFailure
  notice "Application closed"

proc stop*(app: Application) =
  app.status = ApplicationStatus.Stopping
