import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:tourism_mobile/core/design/app_typography.dart';
import 'package:tourism_mobile/core/network/client_event_id.dart';
import 'package:tourism_mobile/features/route_publish/domain/publish_route.dart';
import 'package:tourism_mobile/features/route_publish/presentation/publish_route_design_tokens.dart';

/// Crimea with a margin, as the server checks it (BACKEND-43).
const _south = 44.2, _west = 32.3, _north = 46.4, _east = 36.8;

bool inCrimea(double lat, double lng) =>
    lat >= _south && lat <= _north && lng >= _west && lng <= _east;

/// Two numbers from what a map app copies: «44.4952, 34.1663»,
/// «44.4952 34.1663» or «44,4952 34,1663». Null when it is not that.
(double, double)? parseCoordinates(String text) {
  final source = text.trim();
  final dotted = RegExp(r'-?\d+\.\d+').allMatches(source).toList();
  // A dot anywhere means dots are decimals; only without one are commas.
  final numbers = source.contains('.')
      ? dotted.map((m) => double.parse(m.group(0)!)).toList()
      : RegExp(r'-?\d+(?:,\d+)?')
            .allMatches(source)
            .map((m) => double.parse(m.group(0)!.replaceAll(',', '.')))
            .toList();
  if (numbers.length != 2) return null;
  return (numbers[0], numbers[1]);
}

/// «Своя точка»: a spring, a viewpoint or a parking that is not in the
/// catalogue (BACKEND-43). Returns the point, or null when cancelled.
Future<RouteLocation?> showAuthorPointSheet(
  BuildContext context, {
  RouteLocation? initial,
}) => showModalBottomSheet<RouteLocation>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: PublishRouteDesignTokens.background,
  builder: (_) => AuthorPointSheet(initial: initial),
);

class AuthorPointSheet extends StatefulWidget {
  const AuthorPointSheet({this.initial, super.key});

  final RouteLocation? initial;

  @override
  State<AuthorPointSheet> createState() => _AuthorPointSheetState();
}

class _AuthorPointSheetState extends State<AuthorPointSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _coords = TextEditingController(
    text: widget.initial == null
        ? ''
        : '${widget.initial!.lat.toStringAsFixed(5)}, '
              '${widget.initial!.lng.toStringAsFixed(5)}',
  );
  late var _kind = widget.initial?.authorKind ?? 'viewpoint';
  var _locating = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _coords.dispose();
    super.dispose();
  }

  Future<void> _here() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _NoLocation();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _coords.text =
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}';
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'Не удалось узнать, где вы. Вставьте координаты из карты',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _save() {
    final name = _name.text.trim();
    final coords = parseCoordinates(_coords.text);
    final error = name.length < 2
        ? 'Назовите точку'
        : coords == null
        ? 'Координаты в виде «44.49520, 34.16630»'
        : !inCrimea(coords.$1, coords.$2)
        ? 'Точка должна быть в Крыму'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      RouteLocation(
        id: widget.initial?.id ?? newClientEventId(),
        name: name,
        subtitle: authorPointKindLabel(_kind),
        lat: coords!.$1,
        lng: coords.$2,
        authorKind: _kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      0,
      18,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'Своя точка' : 'Изменить свою точку',
            style: const TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: PublishRouteDesignTokens.dark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Родник, смотровая или парковка, которых нет в каталоге. Точка '
            'необязательная: за неё не начисляются очки',
            style: TextStyle(
              fontFamily: AppFonts.rubik,
              fontSize: 13,
              color: PublishRouteDesignTokens.secondaryText,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('author-point-name'),
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название',
              hintText: 'Например, родник Кара-Су',
              border: OutlineInputBorder(),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (kind, label) in authorPointKinds)
                ChoiceChip(
                  key: ValueKey('author-point-kind-$kind'),
                  label: Text(label),
                  selected: _kind == kind,
                  showCheckmark: false,
                  // The app's chip theme is for dark surfaces; this sheet
                  // is light, so the colours are set here.
                  labelStyle: TextStyle(
                    fontFamily: AppFonts.rubik,
                    fontSize: 14,
                    color: _kind == kind
                        ? Colors.white
                        : PublishRouteDesignTokens.dark,
                  ),
                  selectedColor: PublishRouteDesignTokens.dark,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE2E2E6)),
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('author-point-coords'),
            controller: _coords,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Координаты',
              hintText: '44.49520, 34.16630',
              helperText:
                  'Скопируйте из любой карты или нажмите «Где я сейчас»',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _locating ? null : () => unawaited(_here()),
              icon: const Icon(Icons.my_location_rounded),
              label: Text(_locating ? 'Ищем вас…' : 'Где я сейчас'),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Координаты точки увидят все, кто откроет маршрут. Не отмечайте '
              'свой дом или частную территорию',
              style: TextStyle(fontFamily: AppFonts.rubik, fontSize: 13),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const ValueKey('author-point-error'),
              style: const TextStyle(
                fontFamily: AppFonts.rubik,
                fontSize: 13,
                color: Color(0xFFE5484D),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            key: const ValueKey('author-point-save'),
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
            ),
            child: Text(
              widget.initial == null ? 'Добавить точку' : 'Сохранить',
            ),
          ),
        ],
      ),
    ),
  );
}

class _NoLocation implements Exception {
  const _NoLocation();
}
