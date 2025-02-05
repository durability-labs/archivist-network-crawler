import std/os
import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import pkg/datastore
import pkg/datastore/typedds
import pkg/metrics

import ./config
import ./list

logScope:
  topics = "main"

declareGauge(example, "testing")

proc startApplication*(config: CrawlerConfig): Future[?!void] {.async.} =
  without exampleStore =? LevelDbDatastore.new(config.dataDir / "example"):
    error "Failed to create datastore"
    return failure("Failed to create datastore")

  let typedDs = TypedDatastore.init(exampleStore)

  proc onExampleMetric(value: int64) =
    example.set(value)

  var exampleList = List.new("example", typedDs, onExampleMetric)
  if err =? (await exampleList.load()).errorOption:
    return failure(err)

  proc aaa() {.async.} =
    var i = 0
    while true:
      trace "a"
      await sleepAsync(1000)
      discard await exampleList.add(Entry(id: $i, value: "str!"))
      inc i

  asyncSpawn aaa()

  await sleepAsync(1000)

  notice "b"
  return success()
