import pkg/chronos
import pkg/questionable/results

import ./state

type Component* = ref object of RootObj

method start*(c: Component, state: State): Future[?!void] {.async, base.} =
  raiseAssert("call to abstract method: component.start")

method stop*(c: Component): Future[?!void] {.async, base.} =
  raiseAssert("call to abstract method: component.stop")
