import '../entities/counter.dart';

/// Pure use case: increments a counter value.
///
/// This function is predictable (same input → same output) and
/// free of side effects, adhering to the Law of Atomic Predictability.
CounterValue incrementCounter(CounterValue current) {
  return current.increment();
}
