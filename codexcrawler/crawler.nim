import pkg/chronicles
import pkg/chronos

import ./dht
import ./list

logScope:
  topics = "crawler"

type Crawler* = ref object
  dht: Dht
  todoNodes: List
  okNodes: List
  nokNodes: List

proc start*(c: Crawler) =
  info "Starting crawler..."

proc new*(T: type Crawler, dht: Dht, todoNodes: List, okNodes: List, nokNodes: List): Crawler =
  Crawler(
    dht: dht,
    todoNodes: todoNodes,
    okNodes: okNodes,
    nokNodes: nokNodes
  )
