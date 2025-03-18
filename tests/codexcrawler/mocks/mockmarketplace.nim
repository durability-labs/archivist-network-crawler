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
    recentSlotFillEventsReturn*: ?!seq[SlotFilled]

method getRecentSlotFillEvents*(m: MarketplaceService): Future[?!seq[SlotFilled]] {.async: (raises: []).} =
  return m.recentSlotFillEventsReturn

proc createMockMarketplaceService*(): MockMarketplaceService =
  MockMarketplaceService()
