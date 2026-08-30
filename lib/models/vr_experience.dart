class VrExperience {
  final String id;
  final String title;
  final String tag;
  final String desc;
  final String img;
  final String badge;
  final String platform;
  final String mode;
  final String language;
  final String performance;
  final String storeLink;
  final String trailerLink;
  final bool isAvailable;

  VrExperience({
    required this.id,
    required this.title,
    required this.tag,
    required this.desc,
    required this.img,
    required this.badge,
    required this.platform,
    required this.mode,
    required this.language,
    required this.performance,
    required this.storeLink,
    required this.trailerLink,
    required this.isAvailable,
  });

  factory VrExperience.fromJson(Map<String, dynamic> json) {
    return VrExperience(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      title: json['title'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      img: json['img'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      language: json['language'] as String? ?? '',
      performance: json['performance'] as String? ?? '',
      storeLink: json['storeLink'] as String? ?? '',
      trailerLink: json['trailerLink'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'tag': tag,
      'desc': desc,
      'img': img,
      'badge': badge,
      'platform': platform,
      'mode': mode,
      'language': language,
      'performance': performance,
      'storeLink': storeLink,
      'trailerLink': trailerLink,
      'isAvailable': isAvailable,
    };
  }
}
