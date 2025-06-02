import std/strutils
import std/strformat
import pkg/ethers
import pkg/upraises
import pkg/questionable
import ./logutils
import ./marketplace
import ./proofs
import ./provider
import ./config
import ./periods

# Copy of nim-codex market.nim
# Edited to remove signing, reward address, etc

logScope:
  topics = "marketplace onchain market"

type
  OnChainMarket* = ref object of RootObj
    contract: Marketplace
    configuration: ?MarketplaceConfig

  Subscription = ref object of RootObj
  MarketError* = object of CatchableError
  MarketSubscription = market.Subscription
  EventSubscription = ethers.Subscription
  OnChainMarketSubscription = ref object of MarketSubscription
    eventSubscription: EventSubscription

  ProofChallenge* = array[32, byte]
  # Event callback signatures:
  OnRequest* =
    proc(id: RequestId, ask: StorageAsk, expiry: uint64) {.gcsafe, upraises: [].}
  OnFulfillment* = proc(requestId: RequestId) {.gcsafe, upraises: [].}
  OnSlotFilled* = proc(requestId: RequestId, slotIndex: uint64) {.gcsafe, upraises: [].}
  OnSlotFreed* = proc(requestId: RequestId, slotIndex: uint64) {.gcsafe, upraises: [].}
  OnSlotReservationsFull* =
    proc(requestId: RequestId, slotIndex: uint64) {.gcsafe, upraises: [].}
  OnRequestCancelled* = proc(requestId: RequestId) {.gcsafe, upraises: [].}
  OnRequestFailed* = proc(requestId: RequestId) {.gcsafe, upraises: [].}
  OnProofSubmitted* = proc(id: SlotId) {.gcsafe, upraises: [].}

  # Marketplace events
  MarketplaceEvent* = Event
  StorageRequested* = object of MarketplaceEvent
    requestId*: RequestId
    ask*: StorageAsk
    expiry*: uint64

  SlotFilled* = object of MarketplaceEvent
    requestId* {.indexed.}: RequestId
    slotIndex*: uint64

  SlotFreed* = object of MarketplaceEvent
    requestId* {.indexed.}: RequestId
    slotIndex*: uint64

  SlotReservationsFull* = object of MarketplaceEvent
    requestId* {.indexed.}: RequestId
    slotIndex*: uint64

  RequestFulfilled* = object of MarketplaceEvent
    requestId* {.indexed.}: RequestId

  RequestCancelled* = object of MarketplaceEvent
    requestId* {.indexed.}: RequestId

  RequestFailed* = object of MarketplaceEvent
    requestId* {.indexed.}: RequestId

  ProofSubmitted* = object of MarketplaceEvent
    id*: SlotId

func new*(_: type OnChainMarket, contract: Marketplace): OnChainMarket =
  OnChainMarket(contract: contract)

proc raiseMarketError(message: string) {.raises: [MarketError].} =
  raise newException(MarketError, message)

proc msgDetail*(e: ref CatchableError): string =
  var msg = e.msg
  if e.parent != nil:
    msg = fmt"{msg} Inner exception: {e.parent.msg}"
  return msg

template convertEthersError(body) =
  try:
    body
  except EthersError as error:
    raiseMarketError(error.msgDetail)
  except CatchableError as error:
    raiseMarketError(error.msg)

proc loadConfig(
    market: OnChainMarket
): Future[?!void] {.async: (raises: [CancelledError, MarketError]).} =
  try:
    without config =? market.configuration:
      let fetchedConfig = await market.contract.configuration()

      market.configuration = some fetchedConfig

    return success()
  except AsyncLockError, EthersError, CatchableError:
    let err = getCurrentException()
    return failure newException(
      MarketError,
      "Failed to fetch the config from the Marketplace contract: " & err.msg,
    )

proc config(
    market: OnChainMarket
): Future[MarketplaceConfig] {.async: (raises: [CancelledError, MarketError]).} =
  without resolvedConfig =? market.configuration:
    if err =? (await market.loadConfig()).errorOption:
      raiseMarketError(err.msg)

    without config =? market.configuration:
      raiseMarketError("Failed to access to config from the Marketplace contract")

    return config

  return resolvedConfig

proc approveFunds(market: OnChainMarket, amount: UInt256) {.async: (raises: [CancelledError]).} =
  raiseAssert("Not available: approveFunds")

proc getZkeyHash*(
    market: OnChainMarket
): Future[?string] {.async: (raises: [CancelledError, MarketError]).} =
  let config = await market.config()
  return some config.proofs.zkeyHash

proc periodicity*(
    market: OnChainMarket
): Future[Periodicity] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let config = await market.config()
    let period = config.proofs.period
    return Periodicity(seconds: period)

proc proofTimeout*(market: OnChainMarket): Future[uint64] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let config = await market.config()
    return config.proofs.timeout

proc repairRewardPercentage*(market: OnChainMarket): Future[uint8] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let config = await market.config()
    return config.collateral.repairRewardPercentage

proc requestDurationLimit*(market: OnChainMarket): Future[uint64] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let config = await market.config()
    return config.requestDurationLimit

proc proofDowntime*(market: OnChainMarket): Future[uint8] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let config = await market.config()
    return config.proofs.downtime

proc getPointer*(market: OnChainMarket, slotId: SlotId): Future[uint8] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let overrides = CallOverrides(blockTag: some BlockTag.pending)
    return await market.contract.getPointer(slotId, overrides)

proc myRequests*(market: OnChainMarket): Future[seq[RequestId]] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    return await market.contract.myRequests

proc mySlots*(market: OnChainMarket): Future[seq[SlotId]] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let slots = await market.contract.mySlots()
    debug "Fetched my slots", numSlots = len(slots)

    return slots

proc requestStorage(market: OnChainMarket, request: StorageRequest) {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    debug "Requesting storage"
    await market.approveFunds(request.totalPrice())
    discard await market.contract.requestStorage(request).confirm(1)

proc getRequest*(
    market: OnChainMarket, id: RequestId
): Future[?StorageRequest] {.async: (raises: [CancelledError, MarketError]).} =
  let key = $id

  convertEthersError:
    try:
      let request = await market.contract.getRequest(id)
      return some request
    except Marketplace_UnknownRequest:
      return none StorageRequest

proc requestState*(
    market: OnChainMarket, requestId: RequestId
): Future[?RequestState] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    try:
      let overrides = CallOverrides(blockTag: some BlockTag.pending)
      return some await market.contract.requestState(requestId, overrides)
    except Marketplace_UnknownRequest:
      return none RequestState

proc slotState*(market: OnChainMarket, slotId: SlotId): Future[SlotState] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let overrides = CallOverrides(blockTag: some BlockTag.pending)
    return await market.contract.slotState(slotId, overrides)

proc getRequestEnd*(market: OnChainMarket, id: RequestId): Future[uint64] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    return (await market.contract.requestEnd(id)).uint64

proc requestExpiresAt*(market: OnChainMarket, id: RequestId): Future[uint64] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    return (await market.contract.requestExpiry(id)).uint64

proc getHost(
    market: OnChainMarket, requestId: RequestId, slotIndex: uint64
): Future[?Address] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let slotId = slotId(requestId, slotIndex)
    let address = await market.contract.getHost(slotId)
    if address != Address.default:
      return some address
    else:
      return none Address

proc currentCollateral*(
    market: OnChainMarket, slotId: SlotId
): Future[UInt256] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    return await market.contract.currentCollateral(slotId)

proc getActiveSlot*(market: OnChainMarket, slotId: SlotId): Future[?Slot] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    try:
      return some await market.contract.getActiveSlot(slotId)
    except Marketplace_SlotIsFree:
      return none Slot

proc fillSlot(
    market: OnChainMarket,
    requestId: RequestId,
    slotIndex: uint64,
    proof: Groth16Proof,
    collateral: UInt256,
) {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    logScope:
      requestId
      slotIndex

    await market.approveFunds(collateral)
    trace "calling fillSlot on contract"
    discard await market.contract.fillSlot(requestId, slotIndex, proof).confirm(1)
    trace "fillSlot transaction completed"

proc freeSlot*(market: OnChainMarket, slotId: SlotId) {.async: (raises: [CancelledError]).} =
  raiseAssert("Not supported")

proc withdrawFunds(market: OnChainMarket, requestId: RequestId) {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    discard await market.contract.withdrawFunds(requestId).confirm(1)

proc isProofRequired*(market: OnChainMarket, id: SlotId): Future[bool] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    try:
      let overrides = CallOverrides(blockTag: some BlockTag.pending)
      return await market.contract.isProofRequired(id, overrides)
    except Marketplace_SlotIsFree:
      return false

proc willProofBeRequired*(market: OnChainMarket, id: SlotId): Future[bool] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    try:
      let overrides = CallOverrides(blockTag: some BlockTag.pending)
      return await market.contract.willProofBeRequired(id, overrides)
    except Marketplace_SlotIsFree:
      return false

proc getChallenge*(
    market: OnChainMarket, id: SlotId
): Future[ProofChallenge] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let overrides = CallOverrides(blockTag: some BlockTag.pending)
    return await market.contract.getChallenge(id, overrides)

proc submitProof*(market: OnChainMarket, id: SlotId, proof: Groth16Proof) {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    discard await market.contract.submitProof(id, proof).confirm(1)

proc markProofAsMissing*(market: OnChainMarket, id: SlotId, period: Period) {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    discard await market.contract.markProofAsMissing(id, period).confirm(1)

proc canProofBeMarkedAsMissing*(
    market: OnChainMarket, id: SlotId, period: Period
): Future[bool] {.async: (raises: [CancelledError]).} =
  let provider = market.contract.provider
  let contractWithoutSigner = market.contract.connect(provider)
  let overrides = CallOverrides(blockTag: some BlockTag.pending)
  try:
    discard await contractWithoutSigner.markProofAsMissing(id, period, overrides)
    return true
  except EthersError as e:
    trace "Proof cannot be marked as missing", msg = e.msg
    return false

proc reserveSlot*(
    market: OnChainMarket, requestId: RequestId, slotIndex: uint64
) {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    discard await market.contract
    .reserveSlot(
      requestId,
      slotIndex,
      # reserveSlot runs out of gas for unknown reason, but 100k gas covers it
      TransactionOverrides(gasLimit: some 100000.u256),
    )
    .confirm(1)

proc canReserveSlot*(
    market: OnChainMarket, requestId: RequestId, slotIndex: uint64
): Future[bool] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    return await market.contract.canReserveSlot(requestId, slotIndex)

proc subscribeRequests*(
    market: OnChainMarket, callback: OnRequest
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!StorageRequested) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in Request subscription", msg = eventErr.msg
      return

    callback(event.requestId, event.ask, event.expiry)

  convertEthersError:
    let subscription = await market.contract.subscribe(StorageRequested, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeSlotFilled*(
    market: OnChainMarket, callback: OnSlotFilled
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!SlotFilled) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in SlotFilled subscription", msg = eventErr.msg
      return

    callback(event.requestId, event.slotIndex)

  convertEthersError:
    let subscription = await market.contract.subscribe(SlotFilled, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeSlotFilled*(
    market: OnChainMarket,
    requestId: RequestId,
    slotIndex: uint64,
    callback: OnSlotFilled,
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onSlotFilled(eventRequestId: RequestId, eventSlotIndex: uint64) =
    if eventRequestId == requestId and eventSlotIndex == slotIndex:
      callback(requestId, slotIndex)

  convertEthersError:
    return await market.subscribeSlotFilled(onSlotFilled)

proc subscribeSlotFreed*(
    market: OnChainMarket, callback: OnSlotFreed
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!SlotFreed) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in SlotFreed subscription", msg = eventErr.msg
      return

    callback(event.requestId, event.slotIndex)

  convertEthersError:
    let subscription = await market.contract.subscribe(SlotFreed, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeSlotReservationsFull*(
    market: OnChainMarket, callback: OnSlotReservationsFull
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!SlotReservationsFull) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in SlotReservationsFull subscription",
        msg = eventErr.msg
      return

    callback(event.requestId, event.slotIndex)

  convertEthersError:
    let subscription = await market.contract.subscribe(SlotReservationsFull, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeFulfillment(
    market: OnChainMarket, callback: OnFulfillment
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!RequestFulfilled) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in RequestFulfillment subscription", msg = eventErr.msg
      return

    callback(event.requestId)

  convertEthersError:
    let subscription = await market.contract.subscribe(RequestFulfilled, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeFulfillment(
    market: OnChainMarket, requestId: RequestId, callback: OnFulfillment
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!RequestFulfilled) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in RequestFulfillment subscription", msg = eventErr.msg
      return

    if event.requestId == requestId:
      callback(event.requestId)

  convertEthersError:
    let subscription = await market.contract.subscribe(RequestFulfilled, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeRequestCancelled*(
    market: OnChainMarket, callback: OnRequestCancelled
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!RequestCancelled) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in RequestCancelled subscription", msg = eventErr.msg
      return

    callback(event.requestId)

  convertEthersError:
    let subscription = await market.contract.subscribe(RequestCancelled, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeRequestCancelled*(
    market: OnChainMarket, requestId: RequestId, callback: OnRequestCancelled
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!RequestCancelled) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in RequestCancelled subscription", msg = eventErr.msg
      return

    if event.requestId == requestId:
      callback(event.requestId)

  convertEthersError:
    let subscription = await market.contract.subscribe(RequestCancelled, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeRequestFailed*(
    market: OnChainMarket, callback: OnRequestFailed
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!RequestFailed) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in RequestFailed subscription", msg = eventErr.msg
      return

    callback(event.requestId)

  convertEthersError:
    let subscription = await market.contract.subscribe(RequestFailed, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeRequestFailed*(
    market: OnChainMarket, requestId: RequestId, callback: OnRequestFailed
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!RequestFailed) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in RequestFailed subscription", msg = eventErr.msg
      return

    if event.requestId == requestId:
      callback(event.requestId)

  convertEthersError:
    let subscription = await market.contract.subscribe(RequestFailed, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc subscribeProofSubmission*(
    market: OnChainMarket, callback: OnProofSubmitted
): Future[MarketSubscription] {.async: (raises: [CancelledError, MarketError]).} =
  proc onEvent(eventResult: ?!ProofSubmitted) {.upraises: [].} =
    without event =? eventResult, eventErr:
      error "There was an error in ProofSubmitted subscription", msg = eventErr.msg
      return

    callback(event.id)

  convertEthersError:
    let subscription = await market.contract.subscribe(ProofSubmitted, onEvent)
    return OnChainMarketSubscription(eventSubscription: subscription)

proc unsubscribe*(subscription: OnChainMarketSubscription) {.async: (raises: [CancelledError, MarketError]).} =
  try:
    await subscription.eventSubscription.unsubscribe()
  except ProviderError as err:
    raiseMarketError(err.msg)    

proc queryPastSlotFilledEvents*(
    market: OnChainMarket, fromBlock: BlockTag
): Future[seq[SlotFilled]] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    return await market.contract.queryFilter(SlotFilled, fromBlock, BlockTag.latest)

proc queryPastSlotFilledEvents*(
    market: OnChainMarket, blocksAgo: int
): Future[seq[SlotFilled]] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let fromBlock = await market.contract.provider.pastBlockTag(blocksAgo)

    return await market.queryPastSlotFilledEvents(fromBlock)

proc queryPastSlotFilledEvents*(
    market: OnChainMarket, fromTime: int64
): Future[seq[SlotFilled]] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let fromBlock = await market.contract.provider.blockNumberForEpoch(fromTime)
    return await market.queryPastSlotFilledEvents(BlockTag.init(fromBlock))

proc queryPastStorageRequestedEvents*(
    market: OnChainMarket, fromBlock: BlockTag
): Future[seq[StorageRequested]] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    return
      await market.contract.queryFilter(StorageRequested, fromBlock, BlockTag.latest)

proc queryPastStorageRequestedEvents*(
    market: OnChainMarket, blocksAgo: int
): Future[seq[StorageRequested]] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let fromBlock = await market.contract.provider.pastBlockTag(blocksAgo)

    return await market.queryPastStorageRequestedEvents(fromBlock)

proc queryPastStorageRequestedEventsFromTime*(
    market: OnChainMarket, fromTime: int64
): Future[seq[StorageRequested]] {.async: (raises: [CancelledError, MarketError]).} =
  convertEthersError:
    let fromBlock = await market.contract.provider.blockNumberForEpoch(fromTime)

    return await market.queryPastStorageRequestedEvents(BlockTag.init(fromBlock))
