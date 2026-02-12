class DeviceModel {
  final String id; // MAC Address or UUID
  final String name;
  final bool isConnected;
  final DateTime? lastSeen;

  DeviceModel({
    required this.id,
    required this.name,
    this.isConnected = false,
    this.lastSeen,
  });

  DeviceModel copyWith({
    String? id,
    String? name,
    bool? isConnected,
    DateTime? lastSeen,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'],
      name: json['name'],
      isConnected: json['isConnected'] ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isConnected': isConnected,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }
}
