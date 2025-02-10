import pkg/chronos
import pkg/questionable
import pkg/questionable/results
import pkg/asynctest/chronos/unittest

import ../../../codexcrawler/utils/asyncdataevent

type
  ExampleData = object
    s: string

suite "AsyncDataEvent":
  var event: AsyncDataEvent[ExampleData]
  let msg = "Yeah!"

  setup:
    event = newAsyncDataEvent[ExampleData]()

  teardown:
    await event.unsubscribeAll()

  test "Successful event":
    var data = ""
    proc eventHandler(e: ExampleData): Future[?!void] {.async.} =
      data = e.s
      success()

    let s = event.subscribe(eventHandler)

    check:
      isOK(await event.fire(ExampleData(
        s: msg
      )))
      data == msg

    await event.unsubscribe(s)

  test "Failed event preserves error message":
    proc eventHandler(e: ExampleData): Future[?!void] {.async.} =
      failure(msg)

    let s = event.subscribe(eventHandler)
    let fireResult = await event.fire(ExampleData(
      s: "a"
    ))

    check:
      fireResult.isErr
      fireResult.error.msg == msg

    await event.unsubscribe(s)

  test "Emits data to multiple subscribers":
    var
      data1 = ""
      data2 = ""
      data3 = ""

    proc handler1(e: ExampleData): Future[?!void] {.async.} =
      data1 = e.s
      success()
    proc handler2(e: ExampleData): Future[?!void] {.async.} =
      data2 = e.s
      success()
    proc handler3(e: ExampleData): Future[?!void] {.async.} =
      data3 = e.s
      success()

    let
      s1 = event.subscribe(handler1)
      s2 = event.subscribe(handler2)
      s3 = event.subscribe(handler3)

    let fireResult = await event.fire(ExampleData(
        s: msg
    ))

    check:
      fireResult.isOK
      data1 == msg
      data2 == msg
      data3 == msg

    await event.unsubscribe(s1)
    await event.unsubscribe(s2)
    await event.unsubscribe(s3)
