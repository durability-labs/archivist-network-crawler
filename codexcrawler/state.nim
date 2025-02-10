import pkg/chronos
import pkg/questionable/results

import ./config

type
  OnStep = proc(): Future[?!void] {.async: (raises: []), gcsafe.}
  State* = ref object
    config*: Config
    # events
    # appstate

proc whileRunning*(this: State, step: OnStep, delay: Duration) =
  discard
  #todo: while status == running, step(), asyncsleep duration
