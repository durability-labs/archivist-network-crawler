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

  test "iterateAll yields all entries":
    let
      rid1 = genRid()
      rid2 = genRid()
      rid3 = genRid()

    (await store.update(rid1)).tryGet()
    (await store.update(rid2)).tryGet()
    (await store.update(rid3)).tryGet()

    var entries = newSeq[RequestEntry]()
    proc onEntry(entry: RequestEntry): Future[?!void] {.async: (raises: []), gcsafe.} =
      entries.add(entry)
      return success()

    (await store.iterateAll(onEntry)).tryGet()

    check:
      entries.len == 3
      entries[0].id == rid1
      entries[0].lastSeen == clock.setNow
      entries[1].id == rid2
      entries[1].lastSeen == clock.setNow
      entries[2].id == rid3
      entries[2].lastSeen == clock.setNow
