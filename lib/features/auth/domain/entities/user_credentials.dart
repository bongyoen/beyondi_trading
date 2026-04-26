/// Parsed credentials submitted at the login boundary.
///
/// Once constructed, both [id] and [password] are guaranteed to be
/// non-empty. This makes illegal states unrepresentable — no defensive
/// checks needed in core logic (Parse Don't Validate).
class UserCredentials {
  /// Creates [UserCredentials] with the given [id] and [password].
  ///
  /// Throws [AssertionError] if either field is empty.
  const UserCredentials({
    required this.id,
    required this.password,
  }) : assert(id != '', 'User ID must not be empty'),
       assert(password != '', 'Password must not be empty');

  /// The user's login identifier.
  final String id;

  /// The user's password.
  final String password;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserCredentials &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          password == other.password;

  @override
  int get hashCode => Object.hash(id, password);

  @override
  String toString() => 'UserCredentials(id: $id)';
}
