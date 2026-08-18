import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/features/profile/data/public_profile_repository.dart';

void main() {
  test('public user counts reject negatives and extra keys stay unused', () {
    final user = PublicUserProfile.fromJson({
      'id': 'u1',
      'display_name': '<script>alert(1)</script>',
      'followers_count': -12,
      'following_count': 1000000001,
      'liked_by_me': true,
      'role': 'admin',
    });
    expect(user.displayName, '<script>alert(1)</script>');
    expect(user.followersCount, 0);
    expect(user.followingCount, 1000000000);
    expect(user.likedByMe, isTrue);
  });
}
