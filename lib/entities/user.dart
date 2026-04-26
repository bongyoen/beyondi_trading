/// Represents a user in the trading application.
///
/// Parsed at the boundary; once created, the data is trusted throughout
/// the system. All fields are required and immutable.
class User {
  /// Creates a [User] instance.
  ///
  /// Throws [ArgumentError] if [id], [name], or [email] is empty.
  User({
    required this.id,
    required this.name,
    required this.email,
  }) : assert(id.isNotEmpty, 'User id must not be empty'),
       assert(name.isNotEmpty, 'User name must not be empty'),
       assert(email.isNotEmpty, 'User email must not be empty');

  /// Unique identifier for the user.
  final String id;

  /// Display name of the user.
  final String name;

  /// Email address of the user.
  final String email;
}
