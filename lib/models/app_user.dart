class AppUser {
  final String uid;
  final String displayName;
  final String? email;
  final String? phone;
  final String? relationship;
  final String? photoUrl;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.phone,
    this.relationship,
    this.photoUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'relationship': relationship,
        'photoUrl': photoUrl,
        'createdAt': createdAt,
      };

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        displayName: map['displayName'] as String? ?? '',
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        relationship: map['relationship'] as String?,
        photoUrl: map['photoUrl'] as String?,
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}
