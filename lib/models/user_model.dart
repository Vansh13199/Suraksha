class UserModel {
  final String uid;
  final String phoneNumber;
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? profilePicUrl;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.profilePicUrl,
  });

  String get fullName => "${firstName ?? ''} ${lastName ?? ''}".trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth']) : null,
      gender: json['gender'],
      bloodGroup: json['bloodGroup'],
      profilePicUrl: json['profilePicUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'bloodGroup': bloodGroup,
      'profilePicUrl': profilePicUrl,
    };
  }
}
