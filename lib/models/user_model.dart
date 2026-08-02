class UserModel {
  final String uid;
  final String email;
  final String phoneNumber;
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? profilePicUrl;
  final bool isEkycVerified;
  final String? securityQuestion;
  final String? securityAnswer;
  List<String> fcmTokens = [];

  UserModel({
    required this.uid,
    required this.email,
    this.phoneNumber = '',
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.profilePicUrl,
    this.isEkycVerified = false,
    this.securityQuestion,
    this.securityAnswer,
    this.fcmTokens = const [],
  });

  String get fullName => "${firstName ?? ''} ${lastName ?? ''}".trim();
  
  int? get age {
    if (dateOfBirth == null) return null;
    final today = DateTime.now();
    int calculatedAge = today.year - dateOfBirth!.year;
    if (today.month < dateOfBirth!.month || 
        (today.month == dateOfBirth!.month && today.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      dateOfBirth: _parseDate(json['dateOfBirth']),
      gender: json['gender'],
      bloodGroup: json['bloodGroup'],
      profilePicUrl: json['profilePicUrl'],
      isEkycVerified: json['isEkycVerified'] ?? false,
      securityQuestion: json['securityQuestion'],
      securityAnswer: json['securityAnswer'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'bloodGroup': bloodGroup,
      'profilePicUrl': profilePicUrl,
      'isEkycVerified': isEkycVerified,
      'securityQuestion': securityQuestion,
      'securityAnswer': securityAnswer,
      'fcmTokens': fcmTokens,
    };
  }

  static DateTime? _parseDate(dynamic dateString) {
    if (dateString == null) return null;
    final str = dateString.toString();
    
    // Try ISO 8601 first
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed;
    
    // Try common manual formats like DD-MM-YYYY or DD/MM/YYYY
    final parts = str.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        // Assume DD-MM-YYYY if year is > 31
        if (year > 1000) {
          return DateTime(year, month, day);
        } else if (parts[0].length == 4) {
          // Assume YYYY-MM-DD
          return DateTime(int.parse(parts[0]), month, int.parse(parts[2]));
        }
      }
    }
    return null;
  }
}
