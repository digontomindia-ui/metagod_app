class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? avatar;
  final bool isActive;
  final Membership? membership;
  final double walletBalance;
  final bool hasUsedTrial;
  final String? subscriptionStatus;
  final String? plan;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.avatar,
    required this.isActive,
    this.membership,
    this.walletBalance = 0,
    this.hasUsedTrial = false,
    this.subscriptionStatus,
    this.plan,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'USER',
      avatar: (json['avatar'] ?? json['profileImage']) as String?,
      isActive: json['isActive'] as bool? ?? true,
      membership: json['membership'] != null
          ? Membership.fromJson(Map<String, dynamic>.from(json['membership'] as Map))
          : null,
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
      hasUsedTrial: json['hasUsedTrial'] as bool? ?? false,
      subscriptionStatus: json['subscriptionStatus'] as String?,
      plan: json['plan'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'avatar': avatar,
      'isActive': isActive,
      'membership': membership?.toJson(),
      'walletBalance': walletBalance,
      'hasUsedTrial': hasUsedTrial,
      'subscriptionStatus': subscriptionStatus,
      'plan': plan,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class Membership {
  final String plan;
  final DateTime expiresAt;

  Membership({
    required this.plan,
    required this.expiresAt,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      plan: json['plan'] as String? ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan': plan,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
