import pkg/chronos
import pkg/questionable/results

import ./state
import ./metrics
import ./component
import ./components/dht
import ./components/crawler
import ./components/timetracker
import ./components/nodestore

proc createComponents*(state: State): Future[?!seq[Component]] {.async.} =
  var components: seq[Component] = newSeq[Component]()

  without dht =? (await createDht(state)), err:
    return failure(err)

  without nodeStore =? createNodeStore(state), err:
    return failure(err)

  let metrics = createMetrics(state.config.metricsAddress, state.config.metricsPort)

  components.add(nodeStore)
  components.add(dht)
  components.add(Crawler.new(dht, state.config))
  components.add(TimeTracker.new(state.config))
  return success(components)
