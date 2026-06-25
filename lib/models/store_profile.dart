class StoreProfile {
  final String storeId;
  final String name;
  final String address;
  final String logoUrl;
  final bool isLive;

  const StoreProfile({
    required this.storeId,
    required this.name,
    required this.address,
    this.logoUrl = '🏪',
    this.isLive = false,
  });

  factory StoreProfile.fromMap(String storeId, Map<String, dynamic> map) {
    return StoreProfile(
      storeId: storeId,
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '🏪',
      isLive: map['isLive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'logoUrl': logoUrl,
      'isLive': isLive,
    };
  }

  StoreProfile copyWith({
    String? storeId,
    String? name,
    String? address,
    String? logoUrl,
    bool? isLive,
  }) {
    return StoreProfile(
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      isLive: isLive ?? this.isLive,
    );
  }
}
