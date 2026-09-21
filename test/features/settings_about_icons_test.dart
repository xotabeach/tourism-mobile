import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tourism_mobile/core/design/app_iconography.dart';
import 'package:tourism_mobile/features/settings/domain/legal_documents.dart';

void main() {
  test(
    '«О приложении» rows use the designer icons in every colour variant',
    () {
      final assets = [
        for (final document in legalDocuments) document.iconAsset,
        AppIconography.settingsCompanyDetails,
        AppIconography.settingsContacts,
      ];
      expect(assets.toSet(), hasLength(assets.length));
      for (final asset in assets) {
        expect(AppIconography.settingsAssets, contains(asset));
        for (final variant in [
          asset,
          AppIconography.inkAsset(asset),
          AppIconography.accentAsset(asset),
          AppIconography.mutedAsset(asset),
          AppIconography.profileAsset(asset),
        ]) {
          expect(File(variant).existsSync(), isTrue, reason: variant);
        }
      }
    },
  );
}
