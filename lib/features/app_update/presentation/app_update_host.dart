import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/features/app_update/application/app_update_controller.dart';
import 'package:tourism_mobile/features/app_update/domain/version_policy.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the update link; replaceable in tests.
typedef UpdateLauncher = Future<bool> Function(Uri uri);

final updateLauncherProvider = Provider<UpdateLauncher>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Layer over the whole app for the outdated-build prompt (BACKEND-5).
///
/// Lives in MaterialApp's builder, above every route, so the blocking
/// screen covers all of them and no push or deep link can get around it.
class AppUpdateHost extends ConsumerStatefulWidget {
  const AppUpdateHost({super.key});

  @override
  ConsumerState<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends ConsumerState<AppUpdateHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(Future.microtask(_start));
  }

  Future<void> _start() async {
    if (mounted) {
      await ref.read(appUpdateControllerProvider.notifier).onStart();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(appUpdateControllerProvider.notifier).onResumed());
    }
  }

  Future<void> _update(VersionPolicy policy) async {
    final uri = policy.updateUri;
    if (uri == null) {
      return;
    }
    await ref.read(updateLauncherProvider)(uri);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appUpdateControllerProvider);
    if (state.blocked) {
      return _BlockingScreen(
        policy: state.policy,
        onUpdate: () => unawaited(_update(state.policy)),
      );
    }
    if (state.showSoft) {
      return _SoftPrompt(
        policy: state.policy,
        onUpdate: () => unawaited(_update(state.policy)),
        onLater: () =>
            unawaited(ref.read(appUpdateControllerProvider.notifier).later()),
      );
    }
    return const SizedBox.shrink();
  }
}

class _SoftPrompt extends StatelessWidget {
  const _SoftPrompt({
    required this.policy,
    required this.onUpdate,
    required this.onLater,
  });

  final VersionPolicy policy;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final hardAt = policy.hardAt?.toLocal();
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(color: Color(0x66000000), dismissible: false),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Material(
                  color: AppColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.system_update_rounded,
                          size: 36,
                          color: AppColors.accentBlueIcon,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Доступна новая версия',
                          textAlign: TextAlign.center,
                          style: AppTypography.sectionTitle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          policy.message,
                          textAlign: TextAlign.center,
                          style: AppTypography.routeMetadata.copyWith(
                            color: AppColors.secondaryInk,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        if (hardAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'С ${_date(hardAt)} обновление станет обязательным.',
                            textAlign: TextAlign.center,
                            style: AppTypography.routeMetadata.copyWith(
                              color: AppColors.primaryInk,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _PrimaryButton(label: 'Обновить', onPressed: onUpdate),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: onLater,
                          child: Text(
                            'Позже',
                            style: AppTypography.button.copyWith(
                              color: AppColors.secondaryInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockingScreen extends StatelessWidget {
  const _BlockingScreen({required this.policy, required this.onUpdate});

  final VersionPolicy policy;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    // Opaque and absorbing: nothing underneath can be seen, tapped or read
    // out by a screen reader.
    return Material(
      color: AppColors.pageSurface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.system_update_rounded,
                size: 56,
                color: AppColors.accentBlueIcon,
              ),
              const SizedBox(height: 20),
              Text(
                'Нужно обновить приложение',
                textAlign: TextAlign.center,
                style: AppTypography.sectionTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 12),
              Text(
                'Эта версия устарела и больше не поддерживается.',
                textAlign: TextAlign.center,
                style: AppTypography.routeMetadata.copyWith(
                  color: AppColors.primaryInk,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                policy.message,
                textAlign: TextAlign.center,
                style: AppTypography.routeMetadata.copyWith(
                  color: AppColors.secondaryInk,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const Spacer(),
              _PrimaryButton(label: 'Обновить', onPressed: onUpdate),
              const SizedBox(height: 12),
              Text(
                'После скачивания откройте файл и подтвердите установку.',
                textAlign: TextAlign.center,
                style: AppTypography.routeMetadata.copyWith(
                  color: AppColors.secondaryInk,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.activeNavigationFill,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: AppTypography.button),
      ),
    );
  }
}

String _date(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}';
}
