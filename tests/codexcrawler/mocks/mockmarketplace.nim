import pkg/ethers
import pkg/questionable

import ../../../codexcrawler/services/marketplace
import ../../../codexcrawler/services/marketplace/market

logScope:
  topics = "marketplace"

type MockMarketplaceService* = ref object of MarketplaceService
  subNewRequestsCallback*: ?OnNewRequest
  iterRequestsCallback*: ?OnNewRequest

method subscribeToNewRequests*(m: MockMarketplaceService, onNewRequest: OnNewRequest): Future[?!void] {.async: (raises: []).} =
  m.subNewRequestsCallback = some(onNewRequest)
  return success()
  
method iteratePastNewRequestEvents*(m: MockMarketplaceService, onNewRequest: OnNewRequest): Future[?!void] {.async: (raises: []).} =
  m.iterRequestsCallback = some(onNewRequest)
  return success()

proc createMockMarketplaceService*(): MockMarketplaceService =
  MockMarketplaceService(
    subNewRequestsCallback: none(OnNewRequest),
    iterRequestsCallback: none(OnNewRequest)
  )
