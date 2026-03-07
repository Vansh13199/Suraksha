class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? relationship;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.relationship,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      userId: json['userId'] ?? '',
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      relationship: json['relationship'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
    };
  }
}
