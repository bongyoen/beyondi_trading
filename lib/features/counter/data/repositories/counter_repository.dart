/// Abstract repository for counter persistence.
///
/// Defines the boundary contract. Concrete implementations handle
/// storage (local, remote, etc.) while the domain layer depends only
/// on this abstraction.
abstract class CounterRepository {
  /// Loads the persisted counter value.
  ///
  /// Returns 0 if no value has been saved yet.
  Future<int> load();

  /// Persists the given [value].
  Future<void> save(int value);
}
