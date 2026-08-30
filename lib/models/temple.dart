class Temple {
  final String id;
  final String name;
  final String location;
  final String? description;
  final String? coverImage;
  final String? posterImage;
  final bool isLive;
  final bool isVrReady;
  final String? hlsUrl;
  final StreamUrls streamUrls;
  final DateTime createdAt;
  final String? rtmpUrl;
  final int? viewerCount;
  final String? streamStatus;
  final List<String>? resolutions;
  final String? streamKey;
  final List<TempleCamera>? cameras;
  final List<TempleAd>? ads;
  final String? adVideoUrl;
  final bool isAdSkippable;

  Temple({
    required this.id,
    required this.name,
    required this.location,
    this.description,
    this.coverImage,
    this.posterImage,
    required this.isLive,
    required this.isVrReady,
    this.hlsUrl,
    required this.streamUrls,
    required this.createdAt,
    this.rtmpUrl,
    this.viewerCount,
    this.streamStatus,
    this.resolutions,
    this.streamKey,
    this.cameras,
    this.ads,
    this.adVideoUrl,
    this.isAdSkippable = true,
  });

  factory Temple.fromJson(Map<String, dynamic> json) {
    return Temple(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      description: json['description'] as String?,
      coverImage: json['coverImage'] as String?,
      posterImage: json['posterImage'] as String?,
      isLive: json['isLive'] as bool? ?? false,
      isVrReady: json['isVrReady'] as bool? ?? false,
      hlsUrl: json['hlsUrl'] as String?,
      streamUrls: json['streamUrls'] != null
          ? StreamUrls.fromJson(Map<String, dynamic>.from(json['streamUrls'] as Map))
          : StreamUrls(mainCam: '', sideCam: '', altarCam: ''),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      rtmpUrl: json['rtmpUrl'] as String?,
      viewerCount: json['viewerCount'] as int?,
      streamStatus: json['streamStatus'] as String?,
      resolutions: json['resolutions'] != null
          ? List<String>.from(json['resolutions'] as List)
          : null,
      streamKey: json['streamKey'] as String?,
      cameras: json['cameras'] != null
          ? (json['cameras'] as List).map((c) => TempleCamera.fromJson(c)).toList()
          : null,
      ads: json['ads'] != null
          ? (json['ads'] as List).map((a) => TempleAd.fromJson(a)).toList()
          : null,
      adVideoUrl: json['adVideoUrl'] as String?,
      isAdSkippable: json['isAdSkippable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'description': description,
      'coverImage': coverImage,
      'posterImage': posterImage,
      'isLive': isLive,
      'isVrReady': isVrReady,
      'hlsUrl': hlsUrl,
      'streamUrls': streamUrls.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'rtmpUrl': rtmpUrl,
      'viewerCount': viewerCount,
      'streamStatus': streamStatus,
      'resolutions': resolutions,
      'streamKey': streamKey,
      'cameras': cameras?.map((c) => c.toJson()).toList(),
      'ads': ads?.map((a) => a.toJson()).toList(),
      'adVideoUrl': adVideoUrl,
      'isAdSkippable': isAdSkippable,
    };
  }
}

class TempleCamera {
  final String angleName;
  final String rtmpUrl;

  TempleCamera({
    required this.angleName,
    required this.rtmpUrl,
  });

  factory TempleCamera.fromJson(Map<String, dynamic> json) {
    return TempleCamera(
      angleName: json['angleName'] as String? ?? '',
      rtmpUrl: json['rtmpUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'angleName': angleName,
      'rtmpUrl': rtmpUrl,
    };
  }
}

class StreamUrls {
  final String mainCam;
  final String sideCam;
  final String altarCam;

  StreamUrls({
    required this.mainCam,
    required this.sideCam,
    required this.altarCam,
  });

  factory StreamUrls.fromJson(Map<String, dynamic> json) {
    return StreamUrls(
      mainCam: json['mainCam'] as String? ?? '',
      sideCam: json['sideCam'] as String? ?? '',
      altarCam: json['altarCam'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mainCam': mainCam,
      'sideCam': sideCam,
      'altarCam': altarCam,
    };
  }
}

class TempleAd {
  final String videoUrl;
  final bool isSkippable;

  TempleAd({
    required this.videoUrl,
    this.isSkippable = true,
  });

  factory TempleAd.fromJson(Map<String, dynamic> json) {
    return TempleAd(
      videoUrl: json['videoUrl'] as String? ?? '',
      isSkippable: json['isSkippable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoUrl': videoUrl,
      'isSkippable': isSkippable,
    };
  }
}
