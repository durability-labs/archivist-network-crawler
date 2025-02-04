import pkg/chronicles
import pkg/chronos

logScope:
  topics = "main"

proc runApplication*() {.async.} =
  proc aaa() {.async.} =
    while true:
      notice "a"
      await sleepAsync(1000)

  asyncSpawn aaa()
  
  await sleepAsync(1000)

  notice "b"

