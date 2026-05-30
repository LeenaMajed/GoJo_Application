class Place {
  final int placeId;
  final String name;
  final String description;
  final String imageUrl;
  final int durationMinutes;
  final double? rating;
  final String? reasonWhy;
  final String? category;
  final String? costLevel;
  final double? latitude;
  final double? longitude;

  Place({
    required this.placeId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.durationMinutes,
    this.rating,
    this.reasonWhy,
    this.category,
    this.costLevel,
    this.latitude,
    this.longitude,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      placeId: json['place_id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 60,
      rating: (json['rating'] as num?)?.toDouble(),
      reasonWhy: json['reason_why'] as String?,
      category: json['category'] as String?,
      costLevel: json['cost_level'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}