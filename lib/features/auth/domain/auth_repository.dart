class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}

class MeProfile {
  const MeProfile({
    required this.id,
    required this.displayName,
    required this.phone,
    this.avatarUrl,
    this.coverUrl,
    this.notifyPushEnabled = true,
    this.notifySmsEnabled = false,
    this.notifyHapticsEnabled = true,
  });

  final String id;
  final String displayName;
  final String phone;
  final String? avatarUrl;
  final String? coverUrl;
  final bool notifyPushEnabled;
  final bool notifySmsEnabled;
  final bool notifyHapticsEnabled;
}

abstract interface class AuthRepository {
  Future<void> requestOtp({required String displayName, required String phone});

  Future<AuthTokens> verifyOtp({
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  });

  Future<AuthTokens> refresh(String refreshToken);

  Future<void> logout(String refreshToken);

  Future<MeProfile> getMe(String accessToken);

  Future<MeProfile> patchMe({
    required String accessToken,
    String? displayName,
    bool? notifyPushEnabled,
    bool? notifySmsEnabled,
    bool? notifyHapticsEnabled,
  });

  Future<void> requestPhoneChange({
    required String accessToken,
    required String phone,
  });

  Future<MeProfile> verifyPhoneChange({
    required String accessToken,
    required String phone,
    required String code,
    required bool privacyAccepted,
    required bool personalDataAccepted,
  });

  Future<MeProfile> uploadAvatar({
    required String accessToken,
    required String filePath,
  });

  Future<MeProfile> uploadCover({
    required String accessToken,
    required String filePath,
  });
}
