{.deadCodeElim.}
import std/sugar
import ../core

type FilterObservable[T] = object
  observer: Observer[T]
  OnSubscribe: (ptr FilterObservable[T]) -> Disposable

proc onSubscribe*[T](observable: var FilterObservable[T]; observer: Observer[T]): Disposable =
  observable.observer = observer
  observable.OnSubscribe(observable.addr)

proc filter*[T](upstream: var ConceptObservable[T]; predicate: T->bool): FilterObservable[T] =
  let upstream = upstream.addr
  proc OnSubscribe(observable: ptr FilterObservable[T]): Disposable =
    upstream[].subscribe(
      (x:             T) => (if x.predicate: observable[].observer.onNext x),
      (x: ref Exception) => (observable[].observer.onError x),
      (                ) => (observable[].observer.onComplete))
  FilterObservable[T](
    OnSubscribe: OnSubscribe
    )

proc filter*[T](upstream: var ConceptObservable[T]; predicate: (T, int)->bool): FilterObservable[T] =
  let upstream = upstream.addr
  var i: int
  proc OnSubscribe(observable: ptr FilterObservable[T]): Disposable =
    upstream[].subscribe(
      (x:             T) => (
        if x.predicate(i): observable[].observer.onNext x
        inc i),
      (x: ref Exception) => (observable[].observer.onError x),
      (                ) => (observable[].observer.onComplete))
  FilterObservable[T](
    OnSubscribe: OnSubscribe
    )

template test(): untyped {.used.} =
  suite "Operator - Filter":
    test "concept conversion":
      check FilterObservable[int] is ConceptObservable[int]

    setup:
      var results: seq[int]
      var subject: PublishSubject[int]

    test "filter(T)":
      subject
        .filter(x => x mod 3 == 0){}
        .subscribe((x: int) => results.add x)

      subject.next 3, 5, 7, 9, 300
      subject.complete

      check results == [3, 9, 300]

    test "filter(T, i)":
      subject
        .filter((x, i) => (x + i) mod 3 == 0){}
        .subscribe((x: int) => results.add x)

      # (3 + 0), (5 + 1), (7 + 2), (9 + 3), (300 + 4)
      subject.next 3, 5, 7, 9, 300
      subject.complete

      check results == [3, 5, 7, 9]

    test "filter(T) -> filter(T)":
      subject
        .filter(x => x mod 3 == 0){}
        .filter(x => x mod 5 == 0){}
        .subscribe((x: int) => results.add x)

      subject.next 3, 5, 7, 9, 300
      subject.complete

      check results == [300]

    test "filter(T, i) -> filter(T)":
      subject
        .filter((x, i) => (x + i) mod 3 == 0){}
        .filter(x => x mod 5 == 0){}
        .subscribe((x: int) => results.add x)

      # (3 + 0), (5 + 1), (7 + 2), (9 + 3), (300 + 4)
      subject.next 3, 5, 7, 9, 300
      subject.complete

      check results == [5]

when isMainModule:
  import std/unittest
  import reactiveCrown/subjects
  test