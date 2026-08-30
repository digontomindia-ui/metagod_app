class Product {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String category;
  final String? image;
  final bool isTempleShop;
  final String? templeId;
  final List<String> assignedTemples;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    this.image,
    required this.isTempleShop,
    this.templeId,
    required this.assignedTemples,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num? ?? 0).toDouble(),
      stock: json['stock'] as int? ?? 0,
      category: json['category'] as String? ?? '',
      image: json['image']?.toString(),
      isTempleShop: json['isTempleShop'] as bool? ?? false,
      templeId: json['templeId'] is Map
          ? (json['templeId']['_id'] ?? json['templeId']['id'])?.toString()
          : json['templeId']?.toString(),
      assignedTemples: json['assignedTemples'] != null
          ? (json['assignedTemples'] as List).map((item) => item.toString()).toList()
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'category': category,
      'image': image,
      'isTempleShop': isTempleShop,
      'templeId': templeId,
      'assignedTemples': assignedTemples,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
