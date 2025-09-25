import pkg/chronos
import pkg/questionable
import pkg/questionable/results
import ../../../archivistcrawler/services/dht
import ../../../archivistcrawler/types

type MockDht* = ref object of Dht
  routingTable*: seq[Nid]
  getNeighborsArg*: ?Nid
  getNeighborsReturn*: ?!GetNeighborsResponse

method getRoutingTableNodeIds*(d: MockDht): seq[Nid] =
  return d.routingTable

method getNeighbors*(
    d: MockDht, target: Nid
): Future[?!GetNeighborsResponse] {.async: (raises: []).} =
  d.getNeighborsArg = some(target)
  return d.getNeighborsReturn

proc createMockDht*(): MockDht =
  MockDht()
