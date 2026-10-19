class User {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String authProvider;
  final String? createdAt;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    required this.authProvider,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      authProvider: json['auth_provider'] as String? ?? 'email',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'auth_provider': authProvider,
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id && other.email == email;
  }

  @override
  int get hashCode => Object.hash(id, email);
}
