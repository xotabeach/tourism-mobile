import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the person lets the app send their position with a stop mark.
///
/// The map, the "you are here" dot and the distance chip only need the OS
/// permission and keep working without this; the switch controls sending to
/// the server only. [asked] records that the explanation was shown once, so a
/// "Не сейчас" is never asked again until they enable it in settings.
class LocationSharingState {
  const LocationSharingState({this.shareEnabled = true, this.asked = false});

  final bool shareEnabled;
  final bool asked;

  LocationSharingState copyWith({bool? shareEnabled, bool? asked}) =>
      LocationSharingState(
        shareEnabled: shareEnabled ?? this.shareEnabled,
        asked: asked ?? this.asked,
      );
}

class LocationSharingController extends StateNotifier<LocationSharingState> {
  LocationSharingController() : super(const LocationSharingState()) {
    unawaited(_restore());
  }

  static const _shareKey = 'settings.share_position_with_marks';
  static const _askedKey = 'settings.location_explained';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = LocationSharingState(
        shareEnabled: prefs.getBool(_shareKey) ?? true,
        asked: prefs.getBool(_askedKey) ?? false,
      );
    } on Object {
      // Not critical: fall back to the defaults for this session.
    }
  }

  Future<void> setShareEnabled(bool value) async {
    state = state.copyWith(shareEnabled: value);
    await _write(_shareKey, value);
  }

  Future<void> markAsked() async {
    state = state.copyWith(asked: true);
    await _write(_askedKey, true);
  }

  Future<void> _write(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } on Object {
      // Applied for this session even if it could not be saved.
    }
  }
}

final locationSharingProvider =
    StateNotifierProvider<LocationSharingController, LocationSharingState>(
      (ref) => LocationSharingController(),
    );

Future<bool> osLocationGranted() async {
  try {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  } on Object {
    return false;
  }
}

/// Explains why location helps, once, before the system dialog. Called when
/// the first route is started. Never shown again after "Не сейчас".
Future<void> explainLocationOnce(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(locationSharingProvider.notifier);
  if (ref.read(locationSharingProvider).asked) return;
  if (await osLocationGranted()) {
    await controller.markAsked();
    return;
  }
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.deniedForever) {
    await controller.markAsked();
    return;
  }
  if (!context.mounted) return;
  final allow = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Разрешить геолокацию?'),
      content: const Text(
        'Покажем расстояние до точки и поможем точнее засчитывать '
        'прохождение. Это необязательно.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Не сейчас'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Разрешить'),
        ),
      ],
    ),
  );
  await controller.markAsked();
  if (allow == true) {
    await Geolocator.requestPermission();
  }
}

/// Settings switch: turning it on asks the OS when needed, and sends the
/// person to system settings when the permission was denied for good.
Future<void> setPositionSharing(WidgetRef ref, bool value) async {
  final controller = ref.read(locationSharingProvider.notifier);
  if (!value) {
    await controller.setShareEnabled(false);
    return;
  }
  var granted = await osLocationGranted();
  if (!granted) {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    final requested = await Geolocator.requestPermission();
    granted =
        requested == LocationPermission.whileInUse ||
        requested == LocationPermission.always;
  }
  await controller.markAsked();
  await controller.setShareEnabled(granted);
}
