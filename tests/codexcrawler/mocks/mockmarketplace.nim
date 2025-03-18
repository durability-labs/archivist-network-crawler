import pkg/ethers
import pkg/questionable

import ../../../codexcrawler/services/marketplace
import ../../../codexcrawler/services/marketplace/market

logScope:
  topics = "marketplace"

type MockMarketplaceService* = ref object of MarketplaceService
  recentSlotFillEventsReturn*: ?!seq[SlotFilled]

method getRecentSlotFillEvents*(
    m: MockMarketplaceService
): Future[?!seq[SlotFilled]] {.async: (raises: []).} =
  return m.recentSlotFillEventsReturn

proc createMockMarketplaceService*(): MockMarketplaceService =
  MockMarketplaceService()
