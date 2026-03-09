class User {
  final String email;
  final String password;
  final String? name;
  final String? phone;

  User({required this.email, required this.password, this.name, this.phone});
}
