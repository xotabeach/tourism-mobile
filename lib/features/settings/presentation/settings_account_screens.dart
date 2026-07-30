import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:tourism_mobile/core/design/app_colors.dart';
import 'package:tourism_mobile/core/design/app_radii.dart';
import 'package:tourism_mobile/core/design/app_shadows.dart';
import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/errors/app_failure.dart';
import 'package:tourism_mobile/core/theme/app_images.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';
import 'package:tourism_mobile/features/profile/application/profile_providers.dart';
import 'package:tourism_mobile/features/settings/presentation/settings_widgets.dart';
import 'package:tourism_mobile/routing/app_router.dart';

class SettingsAccountScreen extends ConsumerWidget {
  const SettingsAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final name = session.displayName?.trim().isNotEmpty == true
        ? session.displayName!.trim()
        : 'Путешественник';
    final phone = session.phone?.trim().isNotEmpty == true
        ? session.phone!.trim()
        : 'Верификация по номеру';
    return SettingsScaffold(
      title: 'Настройки профиля:',
      children: [
        SettingsNavTile(
          title: 'Сменить имя',
          subtitle: name,
          icon: Icons.badge_outlined,
          onTap: () => context.pushNamed(AppRouteNames.settingsChangeName),
        ),
        SettingsNavTile(
          title: 'Сменить фото',
          subtitle: 'Профиль и обложка профиля',
          icon: Icons.photo_camera_outlined,
          onTap: () => context.pushNamed(AppRouteNames.settingsChangePhoto),
        ),
        SettingsNavTile(
          title: 'Сменить номер телефона',
          subtitle: phone,
          icon: Icons.smartphone_outlined,
          onTap: () => context.pushNamed(AppRouteNames.settingsChangePhone),
        ),
        SettingsNavTile(
          title: 'Сменить предпочтения',
          subtitle: 'Пройти текст по интересам сначала',
          icon: Icons.favorite_border_rounded,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Тест предпочтений появится позже')),
            );
          },
        ),
        SettingsChatCta(
          onTap: () => context.pushNamed(AppRouteNames.settingsChat),
        ),
      ],
    );
  }
}

class SettingsChangeNameScreen extends ConsumerStatefulWidget {
  const SettingsChangeNameScreen({super.key});

  @override
  ConsumerState<SettingsChangeNameScreen> createState() =>
      _SettingsChangeNameScreenState();
}

class _SettingsChangeNameScreenState
    extends ConsumerState<SettingsChangeNameScreen> {
  late final TextEditingController _controller;
  var _privacy = false;
  var _pdn = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(sessionProvider).displayName ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    if (!_privacy || !_pdn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужно принять оба согласия')),
      );
      return;
    }
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > 80) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите корректное имя')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).updateDisplayName(name);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Имя обновлено')));
      context.pop();
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Сменить имя:',
      spaceChildren: false,
      children: [
        SettingsTextField(
          controller: _controller,
          hintText: 'Введите новое имя',
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        _CircleConsent(
          linkLabel: 'политикой конфиденциальности',
          value: _privacy,
          onChanged: (v) => setState(() => _privacy = v),
        ),
        const SizedBox(height: 10),
        _CircleConsent(
          linkLabel: 'обработкой персональных данных',
          value: _pdn,
          onChanged: (v) => setState(() => _pdn = v),
        ),
        const SizedBox(height: 16),
        SettingsPrimaryButton(
          label: _busy ? 'Сохраняем…' : 'Сохранить новое имя',
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 16),
        Text(
          '* Имя будет измененно только после проверки модерацией',
          style: AppTypography.settingsRowSubtitle.copyWith(fontSize: 11),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class SettingsChangePhotoScreen extends ConsumerStatefulWidget {
  const SettingsChangePhotoScreen({super.key});

  @override
  ConsumerState<SettingsChangePhotoScreen> createState() =>
      _SettingsChangePhotoScreenState();
}

class _SettingsChangePhotoScreenState
    extends ConsumerState<SettingsChangePhotoScreen> {
  var _busy = false;

  Future<void> _pickAndUpload({required bool cover}) async {
    if (_busy) {
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (file == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final session = ref.read(sessionProvider.notifier);
      if (cover) {
        await session.uploadCover(file.path);
      } else {
        await session.uploadAvatar(file.path);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cover ? 'Обложка обновлена' : 'Фото профиля обновлено'),
        ),
      );
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final coverProvider = _imageProvider(
      networkUrl: profile.coverImageUrl,
      asset: profile.coverImageAsset,
    );
    final avatarProvider = _imageProvider(
      networkUrl: profile.avatarImageUrl,
      asset: profile.avatarImageAsset,
    );

    return SettingsScaffold(
      title: 'Сменить фото:',
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface,
            borderRadius: BorderRadius.circular(AppRadii.settingsTile),
            boxShadow: AppShadows.settingsTile,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Фото обложки:',
                  style: AppTypography.settingsRowTitle,
                ),
                const SizedBox(height: 12),
                _PhotoPreview(
                  height: 176,
                  borderRadius: BorderRadius.circular(AppRadii.settingsTile),
                  image: coverProvider,
                  overlayAlpha: 0.35,
                  onTap: _busy ? () {} : () => _pickAndUpload(cover: true),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: SettingsColors.hairline),
                const SizedBox(height: 20),
                const Text(
                  'Фото профиля:',
                  style: AppTypography.settingsRowTitle,
                ),
                const SizedBox(height: 12),
                Center(
                  child: _PhotoPreview(
                    height: 156,
                    width: 156,
                    borderRadius: BorderRadius.circular(999),
                    image: avatarProvider,
                    overlayAlpha: 0.55,
                    onTap: _busy ? () {} : () => _pickAndUpload(cover: false),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: SettingsColors.hairline),
                const SizedBox(height: 12),
                Text(
                  _busy
                      ? 'Загружаем…'
                      : '* Изменения вступят в силу только после проверки фотографий модерацией',
                  style: AppTypography.settingsRowSubtitle.copyWith(
                    fontSize: 11,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        SettingsChatCta(
          onTap: () => context.pushNamed(AppRouteNames.settingsChat),
        ),
      ],
    );
  }

  ImageProvider _imageProvider({
    required String? networkUrl,
    required String asset,
  }) {
    if (networkUrl != null && networkUrl.isNotEmpty) {
      if (networkUrl.startsWith('file://')) {
        return FileImage(File(Uri.parse(networkUrl).toFilePath()));
      }
      return AppImages.imageProvider(
        resolvedUrl: networkUrl,
        assetFallback: asset,
      );
    }
    return AssetImage(asset);
  }
}

class SettingsChangePhoneScreen extends ConsumerStatefulWidget {
  const SettingsChangePhoneScreen({super.key});

  @override
  ConsumerState<SettingsChangePhoneScreen> createState() =>
      _SettingsChangePhoneScreenState();
}

class _SettingsChangePhoneScreenState
    extends ConsumerState<SettingsChangePhoneScreen> {
  final _controller = TextEditingController();
  var _confirmStep = false;
  final _codeControllers = List.generate(4, (_) => TextEditingController());
  var _privacy = false;
  var _pdn = false;
  var _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _requestCode() async {
    final phone = _controller.text.trim();
    if (phone.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите номер телефона')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).requestPhoneChange(phone);
      if (!mounted) {
        return;
      }
      setState(() => _confirmStep = true);
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verify() async {
    if (!_privacy || !_pdn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужно принять оба согласия')),
      );
      return;
    }
    final code = _codeControllers.map((c) => c.text).join();
    if (code.length != 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите код из SMS')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .verifyPhoneChange(
            phone: _controller.text.trim(),
            code: code,
            privacyAccepted: _privacy,
            personalDataAccepted: _pdn,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Номер обновлён')));
      context.pop();
    } on AppFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScaffold(
      title: 'Сменить номер телефона:',
      spaceChildren: false,
      children: _confirmStep ? _confirmChildren() : _phoneChildren(),
    );
  }

  List<Widget> _phoneChildren() {
    return [
      SettingsTextField(
        controller: _controller,
        hintText: 'Введите новый номер телефона',
        keyboardType: TextInputType.phone,
        maxLength: 20,
      ),
      const SizedBox(height: 16),
      SettingsPrimaryButton(
        label: _busy ? 'Отправляем…' : 'Продолжить',
        onPressed: _busy ? null : _requestCode,
      ),
    ];
  }

  List<Widget> _confirmChildren() {
    return [
      Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: TextField(
                  controller: _codeControllers[i],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: AppTypography.settingsRowTitle.copyWith(fontSize: 18),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: SettingsColors.fieldFill,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD5D5D5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD5D5D5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: SettingsColors.accent,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && i < 3) {
                      FocusScope.of(context).nextFocus();
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 16),
      _CircleConsent(
        linkLabel: 'политикой конфиденциальности',
        value: _privacy,
        onChanged: (v) => setState(() => _privacy = v),
      ),
      const SizedBox(height: 10),
      _CircleConsent(
        linkLabel: 'обработкой персональных данных',
        value: _pdn,
        onChanged: (v) => setState(() => _pdn = v),
      ),
      const SizedBox(height: 16),
      SettingsPrimaryButton(
        label: _busy ? 'Сохраняем…' : 'Сохранить новое номер',
        onPressed: _busy ? null : _verify,
      ),
    ];
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.height,
    required this.borderRadius,
    required this.image,
    required this.onTap,
    required this.overlayAlpha,
    this.width,
  });

  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final ImageProvider image;
  final VoidCallback onTap;
  final double overlayAlpha;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              image: DecorationImage(
                image: image,
                fit: BoxFit.cover,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: Colors.black.withValues(alpha: overlayAlpha),
              ),
              child: const Center(
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleConsent extends StatelessWidget {
  const _CircleConsent({
    required this.linkLabel,
    required this.value,
    required this.onChanged,
  });

  final String linkLabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: value
                    ? SettingsColors.accent
                    : SettingsColors.checkboxBorder,
                width: 1.8,
              ),
              color: value ? SettingsColors.accent : Colors.transparent,
            ),
            child: value
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTypography.settingsRowSubtitle.copyWith(
                  color: AppColors.settingsInk,
                  height: 1.35,
                ),
                children: [
                  const TextSpan(text: 'Я соглашаюсь\nс '),
                  TextSpan(
                    text: linkLabel,
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppColors.settingsInk,
                    ),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
