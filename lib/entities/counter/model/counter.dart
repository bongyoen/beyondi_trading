/// Immutable value object representing a counter value.
///
/// Parsed at the boundary — once constructed, the value is trusted
/// to be a valid integer.
class CounterValue {
  /// Creates a [CounterValue] with the given [value].
  const CounterValue(this.value);

  /// The current count value.
  final int value;

  /// Returns a new [CounterValue] with the value incremented by 1.
  CounterValue increment() => CounterValue(value + 1);
}
