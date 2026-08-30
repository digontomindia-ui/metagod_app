class Address {
  final String id;
  final String name;
  final String phone;
  final String houseNo;
  final String area;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final String type;
  final bool isDefault;

  Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.houseNo,
    required this.area,
    this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    this.type = 'Home',
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      houseNo: json['houseNo'] ?? '',
      area: json['area'] ?? '',
      landmark: json['landmark'],
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      type: json['type'] ?? 'Home',
      isDefault: json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'houseNo': houseNo,
      'area': area,
      'landmark': landmark,
      'city': city,
      'state': state,
      'pincode': pincode,
      'type': type,
      'isDefault': isDefault,
    };
  }

  String get formattedAddress {
    final parts = [
      houseNo,
      area,
      if (landmark != null && landmark!.isNotEmpty) landmark,
      city,
      state,
      pincode,
    ].where((e) => e != null && e.isNotEmpty).toList();
    return parts.join(', ');
  }
}
