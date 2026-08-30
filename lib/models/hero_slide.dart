class HeroSlide {
  final String id;
  final String bg;
  final String badge;
  final String title;
  final String highlight;
  final String desc;
  final String cta1;
  final String cta2;
  final String link1;
  final String link2;
  final int order;

  HeroSlide({
    required this.id,
    required this.bg,
    required this.badge,
    required this.title,
    required this.highlight,
    required this.desc,
    required this.cta1,
    required this.cta2,
    required this.link1,
    required this.link2,
    required this.order,
  });

  factory HeroSlide.fromJson(Map<String, dynamic> json) {
    return HeroSlide(
      id: json['_id']?.toString() ?? '',
      bg: json['bg']?.toString() ?? '',
      badge: json['badge']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      highlight: json['highlight']?.toString() ?? '',
      desc: json['desc']?.toString() ?? '',
      cta1: json['cta1']?.toString() ?? '',
      cta2: json['cta2']?.toString() ?? '',
      link1: json['link1']?.toString() ?? '',
      link2: json['link2']?.toString() ?? '',
      order: json['order'] is num ? (json['order'] as num).toInt() : 0,
    );
  }
}
