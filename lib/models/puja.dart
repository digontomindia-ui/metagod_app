class TempleIdRef {
  final String id;
  final String name;
  final String location;

  TempleIdRef({
    required this.id,
    required this.name,
    required this.location,
  });

  factory TempleIdRef.fromJson(dynamic json) {
    if (json is Map) {
      return TempleIdRef(
        id: (json['_id'] ?? json['id'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        location: (json['location'] ?? '') as String,
      );
    }
    return TempleIdRef(
      id: json?.toString() ?? '',
      name: '',
      location: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'location': location,
    };
  }
}

class Puja {
  final String id;
  final TempleIdRef? templeId;
  final String name;
  final double price;
  final String duration;
  final String benefits;
  final String image;
  final DateTime createdAt;

  Puja({
    required this.id,
    this.templeId,
    required this.name,
    required this.price,
    required this.duration,
    required this.benefits,
    required this.image,
    required this.createdAt,
  });

  factory Puja.fromJson(Map<String, dynamic> json) {
    return Puja(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      templeId: json['templeId'] != null ? TempleIdRef.fromJson(json['templeId']) : null,
      name: (json['name'] ?? '') as String,
      price: (json['price'] ?? 0).toDouble(),
      duration: (json['duration'] ?? '') as String,
      benefits: (json['benefits'] ?? '') as String,
      image: (json['image'] ?? '') as String,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templeId': templeId?.toJson(),
      'name': name,
      'price': price,
      'duration': duration,
      'benefits': benefits,
      'image': image,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
