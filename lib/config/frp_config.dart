class FRPConfig {
  /// The Google Account ID(s) or Enterprise ID(s) used for Factory Reset Protection.
  /// Replace 'YOUR_GOOGLE_ACCOUNT_ID_HERE' with your actual Google Account ID (a long integer string like '123456789012345678901').
  /// If the user factory resets the phone, they will be forced to log into this specific Google Account to unlock it.
  static const List<String> accountIds = [
    '113415044536067329262',
    '106755222521045337373'
  ];
}
