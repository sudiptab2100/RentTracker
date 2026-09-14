/// The signed-in flat owner's profile document, stored at `users/{uid}`.
class Owner {
  final String uid;
  final String displayName;
  final String email;
  final String phone;

  const Owner({
    required this.uid,
    this.displayName = '',
    this.email = '',
    this.phone = '',
  });

  factory Owner.fromMap(String uid, Map<String, dynamic> map) => Owner(
        uid: uid,
        displayName: (map['displayName'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        phone: (map['phone'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'phone': phone,
      };
}
