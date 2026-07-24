import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local session for Phase 5 UI. Real tokens/auth land in Phase 6.
class SessionState {
  const SessionState({
    this.onboardingCompleted = false,
    this.displayName,
    this.phone,
  });

  final bool onboardingCompleted;
  final String? displayName;
  final String? phone;

  SessionState copyWith({
    bool? onboardingCompleted,
    String? displayName,
    String? phone,
  }) {
    return SessionState(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
    );
  }
}

class SessionController extends StateNotifier<SessionState> {
  SessionController([SessionState? initial])
    : super(initial ?? const SessionState());

  void saveIdentity({required String displayName, required String phone}) {
    state = state.copyWith(
      displayName: displayName.trim(),
      phone: phone.trim(),
    );
  }

  /// Mock OTP accept — no network. Phase 6 replaces with real verification.
  void completeOnboarding({String? displayName}) {
    state = state.copyWith(
      onboardingCompleted: true,
      displayName: displayName?.trim() ?? state.displayName,
    );
  }

  void resetOnboarding() {
    state = const SessionState();
  }
}

final sessionProvider = StateNotifierProvider<SessionController, SessionState>((
  ref,
) {
  return SessionController();
});
