class StoreItem {
  final String itemId;
  final String storeId;
  final String name;
  final double price;
  final bool isAvailable;

  const StoreItem({
    required this.itemId,
    required this.storeId,
    required this.name,
    required this.price,
    this.isAvailable = true,
  });

  factory StoreItem.fromMap(String itemId, Map<String, dynamic> map) {
    return StoreItem(
      itemId: itemId,
      storeId: map['storeId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      isAvailable: map['isAvailable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'price': price,
      'isAvailable': isAvailable,
    };
  }

  StoreItem copyWith({
    String? itemId,
    String? storeId,
    String? name,
    double? price,
    bool? isAvailable,
  }) {
    return StoreItem(
      itemId: itemId ?? this.itemId,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
