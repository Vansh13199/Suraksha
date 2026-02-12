class Validators {

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final cleaned = value.replaceAll(' ', '');

    // Allow only India numbers for now
    final regex = RegExp(r'^(\+91)?[6-9]\d{9}$');

    if (!regex.hasMatch(cleaned)) {
      return 'Enter a valid Indian mobile number';
    }

    return null;
  }

  /// ✅ OTP must be exactly 6 digits
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP is required';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'OTP must be 6 digits';
    }

    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }

    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }

    return null;
  }
}
