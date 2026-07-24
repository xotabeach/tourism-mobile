import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tourism_mobile/core/theme/app_colors.dart';

class AppShellScreen extends StatelessWidget {
  const AppShellScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white.withValues(alpha: 0.64)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      index: 0,
                      label: 'Главная',
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      selected: navigationShell.currentIndex == 0,
                      onTap: _onDestinationSelected,
                    ),
                    _NavItem(
                      index: 1,
                      label: 'Маршруты',
                      icon: Icons.workspaces_outline,
                      selectedIcon: Icons.workspaces_rounded,
                      selected: navigationShell.currentIndex == 1,
                      onTap: _onDestinationSelected,
                    ),
                    _NavItem(
                      index: 2,
                      label: 'Подобрать',
                      icon: Icons.add_circle_outline_rounded,
                      selectedIcon: Icons.add_circle_outline_rounded,
                      selected: navigationShell.currentIndex == 2,
                      onTap: _onDestinationSelected,
                    ),
                    _NavItem(
                      index: 3,
                      label: 'Места',
                      icon: Icons.map_outlined,
                      selectedIcon: Icons.map_rounded,
                      selected: navigationShell.currentIndex == 3,
                      onTap: _onDestinationSelected,
                    ),
                    _NavItem(
                      index: 4,
                      label: 'Профиль',
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      selected: navigationShell.currentIndex == 4,
                      onTap: _onDestinationSelected,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? AppColors.ink
              : Colors.white.withValues(alpha: 0.54),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onTap(index),
            child: SizedBox.square(
              dimension: selected ? 58 : 48,
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected
                    ? Colors.white
                    : Colors.black.withValues(alpha: 0.48),
                size: selected ? 31 : 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
