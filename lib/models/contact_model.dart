class ContactModel {
  final String id;
  final String name;
  final String phoneNumber;
  final int priority; // 1 = Highest

  ContactModel({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.priority = 1,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      priority: json['priority'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'priority': priority,
    };
  }
}
