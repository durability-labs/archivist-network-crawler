import pkg/chronicles
import pkg/chronos

import pkg/metrics

import ./list

logScope:
  topics = "main"

declareGauge(example, "testing")

proc startApplication*() {.async.} =
  proc onExampleMetric(value: int64) =
    example.set(value)
  var exampleList = List[string].new(onExampleMetric)

  proc aaa() {.async.} =
    while true:
      notice "a"
      await sleepAsync(1000)
      exampleList.add("str!")


  asyncSpawn aaa()

  await sleepAsync(1000)

  notice "b"
