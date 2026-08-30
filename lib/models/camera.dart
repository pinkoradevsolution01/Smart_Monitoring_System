/// Camera model for multi-camera CCTV system
class Camera {
  final int? id;
  final String name;
  final String url;
  final String type; // 'rtsp', 'http', 'https', 'v380'
  final int position; // Grid position for display
  final bool isActive;
  final DateTime createdAt;
  final String? username; // For authenticated cameras (V380 Pro, etc.)
  final String? password; // For authenticated cameras

  Camera({
    this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.position,
    this.isActive = true,
    DateTime? createdAt,
    this.username,
    this.password,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'position': position,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'username': username,
      'password': password,
    };
  }

  factory Camera.fromMap(Map<String, dynamic> map) {
    return Camera(
      id: map['id'] as int?,
      name: map['name'] as String,
      url: map['url'] as String,
      type: map['type'] as String,
      position: map['position'] as int,
      isActive: (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      username: map['username'] as String?,
      password: map['password'] as String?,
    );
  }

  Camera copyWith({
    int? id,
    String? name,
    String? url,
    String? type,
    int? position,
    bool? isActive,
    DateTime? createdAt,
    String? username,
    String? password,
  }) {
    return Camera(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  /// Get the full authenticated RTSP URL with credentials embedded
  String getAuthenticatedUrl() {
    if (username == null || password == null || username!.isEmpty) {
      return url;
    }

    // Parse the URL and inject credentials
    final uri = Uri.parse(url);
    if (uri.scheme == 'rtsp') {
      // Format: rtsp://username:password@host:port/path
      return 'rtsp://$username:$password@${uri.host}:${uri.port}${uri.path}';
    }

    return url;
  }
}
