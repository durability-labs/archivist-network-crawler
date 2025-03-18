import pkg/ethers
import pkg/questionable

import ./marketplace/market
import ./marketplace/marketplace
import ../config
import ../component
import ../state

logScope:
  topics = "marketplace"

type
  MockMarketplaceService* = ref object of MarketplaceService
    zkeyHashReturn*: ?!string

method getZkeyhash*(m: MockMarketplaceService): Future[?!string] {.async: (raises: []).} =
  return m.zkeyHashReturn

proc createMockMarketplaceService*(): MockMarketplaceService =
  MockMarketplaceService()
