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
  });

  final String id;
  final String displayName;
  final String phone;
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
    required String displayName,
  });
}
