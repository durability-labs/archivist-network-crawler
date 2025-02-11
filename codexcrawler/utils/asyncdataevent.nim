import pkg/questionable
import pkg/questionable/results
import pkg/chronos

type
  AsyncDataEventSubscription* = ref object
    key: EventQueueKey
    listenFuture: Future[void]
    fireEvent: AsyncEvent
    lastResult: ?!void
    inHandler: bool
    delayedUnsubscribe: bool

  AsyncDataEvent*[T] = ref object
    queue: AsyncEventQueue[?T]
    subscriptions: seq[AsyncDataEventSubscription]

  AsyncDataEventHandler*[T] = proc(data: T): Future[?!void]

proc newAsyncDataEvent*[T](): AsyncDataEvent[T] =
  AsyncDataEvent[T](
    queue: newAsyncEventQueue[?T](), subscriptions: newSeq[AsyncDataEventSubscription]()
  )

proc performUnsubscribe[T](
    event: AsyncDataEvent[T], subscription: AsyncDataEventSubscription
) {.async.} =
  if subscription in event.subscriptions:
    await subscription.listenFuture.cancelAndWait()
    event.subscriptions.delete(event.subscriptions.find(subscription))

proc subscribe*[T](
    event: AsyncDataEvent[T], handler: AsyncDataEventHandler[T]
): AsyncDataEventSubscription =
  var subscription = AsyncDataEventSubscription(
    key: event.queue.register(),
    listenFuture: newFuture[void](),
    fireEvent: newAsyncEvent(),
    inHandler: false,
    delayedUnsubscribe: false,
  )

  proc listener() {.async.} =
    while true:
      let items = await event.queue.waitEvents(subscription.key)
      for item in items:
        if data =? item:
          subscription.inHandler = true
          subscription.lastResult = (await handler(data))
          subscription.inHandler = false
      subscription.fireEvent.fire()

  subscription.listenFuture = listener()

  event.subscriptions.add(subscription)
  subscription

proc fire*[T](event: AsyncDataEvent[T], data: T): Future[?!void] {.async.} =
  event.queue.emit(data.some)
  var toUnsubscribe = newSeq[AsyncDataEventSubscription]()
  for sub in event.subscriptions:
    await sub.fireEvent.wait()
    if err =? sub.lastResult.errorOption:
      return failure(err)
    if sub.delayedUnsubscribe:
      toUnsubscribe.add(sub)

  for sub in toUnsubscribe:
    await event.unsubscribe(sub)

  success()

proc unsubscribe*[T](
    event: AsyncDataEvent[T], subscription: AsyncDataEventSubscription
) {.async.} =
  if subscription.inHandler:
    subscription.delayedUnsubscribe = true
  else:
    await event.performUnsubscribe(subscription)

proc unsubscribeAll*[T](event: AsyncDataEvent[T]) {.async.} =
  let all = event.subscriptions
  for subscription in all:
    await event.unsubscribe(subscription)

proc listeners*[T](event: AsyncDataEvent[T]): int =
  event.subscriptions.len
