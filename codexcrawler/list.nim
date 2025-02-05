import pkg/metrics

type
  OnUpdateMetric = proc(value: int64): void {.gcsafe, raises:[].}
  List*[T] = ref object
    items: seq[T]
    onMetric: OnUpdateMetric

proc new*[T](
  _: type List[T],
  onMetric: OnUpdateMetric
): List[T] =
  List[T](
    items: newSeq[T](),
    onMetric: onMetric
  )

proc add*[T](this: List[T], item: T) =
  this.items.add(item)
  this.onMetric(this.items.len.int64)
