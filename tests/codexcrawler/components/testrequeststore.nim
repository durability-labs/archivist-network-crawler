import std/os
import pkg/chronos
import pkg/questionable/results
import pkg/asynctest/chronos/unittest
import pkg/datastore/typedds

import ../../../codexcrawler/components/requeststore
import ../../../codexcrawler/utils/datastoreutils
import ../../../codexcrawler/types
import ../../../codexcrawler/state
import ../mocks/mockstate
import ../mocks/mockclock
import ../helpers

suite "Requeststore":
  let
    dsPath = getTempDir() / "testds"
    requeststoreName = "requeststore"

  var
    ds: TypedDatastore
    state: MockState
    clock: MockClock
    store: RequestStore

  setup:
    ds = createTypedDatastore(dsPath).tryGet()
    state = createMockState()
    clock = createMockClock()

    store = RequestStore.new(state, ds, clock)

    (await store.start()).tryGet()

  teardown:
    (await store.stop()).tryGet()
    (await ds.close()).tryGet()
    state.checkAllUnsubscribed()
    removeDir(dsPath)

  test "requestEntry encoding":
    let entry = RequestEntry(id: genRid(), lastSeen: 123.uint64)

    let
      bytes = entry.encode()
      decoded = RequestEntry.decode(bytes).tryGet()

    check:
      entry.id == decoded.id
      entry.lastSeen == decoded.lastSeen

  test "update stores a new requestId with current time":
    let rid = genRid()
    (await store.update(rid)).tryGet()

    let
      key = Key.init(requeststoreName / $rid).tryGet()
      stored = (await get[RequestEntry](ds, key)).tryGet()

    check:
      stored.id == rid
      stored.lastSeen == clock.setNow

  test "update updates the current time of an existing requestId with current time":
    let rid = genRid()
    (await store.update(rid)).tryGet()

    clock.setNow = 1234
    (await store.update(rid)).tryGet()

    let
      key = Key.init(requeststoreName / $rid).tryGet()
      stored = (await get[RequestEntry](ds, key)).tryGet()

    check:
      stored.id == rid
      stored.lastSeen == clock.setNow

  test "remove will remove an entry":
    let rid = genRid()
    (await store.update(rid)).tryGet()
    (await store.remove(rid)).tryGet()

    let
      key = Key.init(requeststoreName / $rid).tryGet()
      isStored = (await ds.has(key)).tryGet()

    check:
      isStored == false
