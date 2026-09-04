import 'package:flutter/material.dart';

/// Backend icon keys mapped to Material glyphs.
///
/// Shared by the achievement detail card and the profile tile so the two can
/// never drift: the tile used to draw a bare coloured circle with nothing in
/// it, which read as a placeholder that never finished loading.
/// An unknown key still renders a badge rather than an empty box, so a new
/// achievement can ship from the backend without an app release.
const _achievementIcons = <String, IconData>{
  'marathoner': Icons.directions_run_rounded,
  'same-way': Icons.u_turn_left_rounded,
  'berlin': Icons.flag_rounded,
  'sunrise': Icons.wb_twilight_rounded,
  'water': Icons.waves_rounded,
  'caves': Icons.terrain_rounded,
  'photo': Icons.photo_camera_rounded,
  'night': Icons.nightlight_round,
  'group': Icons.groups_rounded,
  'season': Icons.ac_unit_rounded,
  'local': Icons.place_rounded,
  'guide': Icons.headphones_rounded,
  'distance': Icons.straighten_rounded,
  'favorite': Icons.bookmark_rounded,
  'review': Icons.rate_review_rounded,
  'first-step': Icons.emoji_events_rounded,
  'social': Icons.people_alt_rounded,
  'author': Icons.edit_road_rounded,
  'winter': Icons.severe_cold_rounded,
  'photographer': Icons.image_rounded,
};

IconData achievementIconFor(String slug) =>
    _achievementIcons[slug] ?? Icons.workspace_premium_rounded;
