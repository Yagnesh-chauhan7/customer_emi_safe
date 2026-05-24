class AppVersionModel {
  final int id;
  final String version;
  final String? description;
  final String appUrl;
  final bool isForceUpdate;
  final DateTime createdAt;

  AppVersionModel({
    required this.id,
    required this.version,
    this.description,
    required this.appUrl,
    required this.isForceUpdate,
    required this.createdAt,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      id: json['id'] as int,
      version: json['version'] as String,
      description: json['description'] as String?,
      appUrl: json['app_url'] as String,
      isForceUpdate: json['is_force_update'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
