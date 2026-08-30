import 'puja.dart';

class Booking {
  final String id;
  final dynamic puja; // Can be Puja object, Map, or String ID
  final dynamic temple; // Can be TempleIdRef, Map, or String ID
  final String date;
  final String name;
  final String phone;
  final String gothra;
  final String sankalp;
  final String status;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.puja,
    required this.temple,
    required this.date,
    required this.name,
    required this.phone,
    required this.gothra,
    required this.sankalp,
    required this.status,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      puja: json['pujaId'],
      temple: json['templeId'] != null ? TempleIdRef.fromJson(json['templeId']) : null,
      date: json['date']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      gothra: json['gothra']?.toString() ?? '',
      sankalp: json['sankalp']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String getPujaName() {
    if (puja is Map) {
      return puja['name']?.toString() ?? '';
    }
    if (puja is Puja) {
      return (puja as Puja).name;
    }
    return puja?.toString() ?? 'Puja';
  }

  double getPujaPrice() {
    if (puja is Map) {
      return (puja['price'] ?? 0.0).toDouble();
    }
    if (puja is Puja) {
      return (puja as Puja).price;
    }
    return 0.0;
  }

  String getPujaImage() {
    if (puja is Map) {
      return puja['image']?.toString() ?? '';
    }
    if (puja is Puja) {
      return (puja as Puja).image;
    }
    return '';
  }

  String getTempleName() {
    if (temple is Map) {
      return temple['name']?.toString() ?? '';
    }
    if (temple is TempleIdRef) {
      return (temple as TempleIdRef).name;
    }
    return temple?.toString() ?? 'Temple';
  }
}
