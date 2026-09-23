import 'package:flutter/material.dart';
import 'package:tourism_mobile/features/profile/domain/profile.dart';

class AchievementProgress extends StatelessWidget {
  const AchievementProgress({required this.achievement, super.key});
  final ProfileAchievement achievement;
  String _number(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final current = achievement.progressCurrent;
    final target = achievement.progressTarget;
    if (achievement.isSoon) return const Text('Скоро');
    if (current == null || target == null || target <= 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        LinearProgressIndicator(value: (current / target).clamp(0.0, 1.0)),
        const SizedBox(height: 4),
        Text('${_number(current)} из ${_number(target)}'),
      ],
    );
  }
}
