import pkg/chronos
import pkg/questionable/results

import ./config
import ./component
import ./components/dht
import ./components/crawler
import ./components/timetracker

proc createComponents*(config: Config): Future[?!seq[Component]] {.async.} =
  var components: seq[Component] = newSeq[Component]()

  without dht =? (await createDht(config)), err:
    return failure(err)

  components.add(dht)
  components.add(Crawler.new(dht, config))
  components.add(TimeTracker.new(config))
  return success(components)
