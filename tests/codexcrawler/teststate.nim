import pkg/chronos
import pkg/questionable/results
import pkg/asynctest/chronos/unittest

import ../../codexcrawler/state
import ./mockstate

suite "State":
  var state: State

  setup:
    # The behavior we're testing is the same for the mock
    state = createMockState()

  test "whileRunning":
    var counter = 0

    proc onStep(): Future[?!void] {.async: (raises: []), gcsafe.} =
      inc counter
      return success()

    await state.whileRunning(onStep, 1.milliseconds)

    while counter < 5:
      await sleepAsync(1.milliseconds)

    state.status = ApplicationStatus.Stopped

    await sleepAsync(10.milliseconds)

    check:
      counter == 5
