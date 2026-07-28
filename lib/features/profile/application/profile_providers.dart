import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/data/mock_profile.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';

final profileProvider = Provider<ProfileSnapshot>((ref) {
  final session = ref.watch(sessionProvider);
  return MockProfile.snapshot(displayName: session.displayName);
});
