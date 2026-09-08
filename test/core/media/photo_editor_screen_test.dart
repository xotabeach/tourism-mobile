import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourism_mobile/core/media/photo_editor_screen.dart';

/// The editor is where a photo stops being "picked" and starts being the one
/// the author chose. These drive the real screen: the confirm button and the
/// switch between several photos are what people actually touch.
Future<File> _photoFile(
  Directory directory,
  String name, {
  int width = 120,
  int height = 90,
  Color color = const Color(0xFF2997FF),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
  return file;
}

/// Lets the screen's real async work (reading and decoding each file) run,
/// then rebuilds. Decoding needs a live isolate, so it cannot be driven by
/// pumping alone.
Future<void> _settleDecoding(WidgetTester tester, int count) async {
  // Polls rather than pumping a fixed number of times: the first decode also
  // pays for engine warm-up, and a spinner on screen rules out pumpAndSettle.
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (_applyEnabled(tester)) {
      // One more round so the remaining photos of a batch decode too.
      for (var j = 0; j < count; j++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      return;
    }
  }
}

Future<void> _pumpEditor(WidgetTester tester, List<File> sources) async {
  await tester.pumpWidget(
    MaterialApp(home: PhotoEditorScreen(sources: sources)),
  );
  await _settleDecoding(tester, sources.length);
}

bool _applyEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.byKey(const ValueKey('photo-editor-apply')))
        .onPressed !=
    null;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('photo-editor-test');
  });

  tearDown(() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  testWidgets('«Готово» works as soon as the photo is on screen', (
    tester,
  ) async {
    final file = (await tester.runAsync(
      () => _photoFile(directory, 'one.png'),
    ))!;

    await _pumpEditor(tester, [file]);

    // No gesture first. The button used to read a size written during the
    // body's layout — one frame after the header was built — so it stayed
    // dead until some unrelated rebuild ran, and people had to nudge the
    // photo before they could confirm it (reported 2026-09-08).
    expect(
      _applyEnabled(tester),
      isTrue,
      reason: 'confirm must not wait for the photo to be touched',
    );
  });

  testWidgets('several photos share one editor and one confirm', (
    tester,
  ) async {
    final files = (await tester.runAsync(() async {
      return [
        await _photoFile(directory, 'a.png'),
        await _photoFile(
          directory,
          'b.png',
          width: 90,
          height: 120,
          color: const Color(0xFFEE4444),
        ),
        await _photoFile(directory, 'c.png'),
      ];
    }))!;

    await _pumpEditor(tester, files);

    // The strip is what makes a batch navigable, and the header says where
    // in the batch you are.
    expect(find.byKey(const ValueKey('photo-editor-strip')), findsOneWidget);
    expect(find.textContaining('1/3'), findsOneWidget);
    expect(_applyEnabled(tester), isTrue);

    await tester.tap(find.byKey(const ValueKey('photo-editor-thumb-2')));
    await tester.pump();
    expect(find.textContaining('3/3'), findsOneWidget);
  });

  testWidgets('a single photo gets no strip', (tester) async {
    final file = (await tester.runAsync(
      () => _photoFile(directory, 'solo.png'),
    ))!;

    await _pumpEditor(tester, [file]);

    expect(find.byKey(const ValueKey('photo-editor-strip')), findsNothing);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('confirming returns one JPEG per photo, in order', (
    tester,
  ) async {
    final files = (await tester.runAsync(() async {
      return [
        await _photoFile(directory, 'x.png'),
        await _photoFile(
          directory,
          'y.png',
          width: 200,
          height: 100,
          color: const Color(0xFF33AA55),
        ),
      ];
    }))!;
    List<Uint8List>? returned;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              returned = await Navigator.of(context).push<List<Uint8List>>(
                MaterialPageRoute(
                  builder: (_) => PhotoEditorScreen(sources: files),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _settleDecoding(tester, files.length);

    await tester.tap(find.byKey(const ValueKey('photo-editor-apply')));
    // Rendering and JPEG-encoding both run for real, the encode on another
    // isolate.
    for (var i = 0; i < 60 && returned == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(returned, isNotNull);
    expect(returned!.length, 2);
    // JPEG, not PNG: at upload resolution a PNG of a photo runs to
    // megabytes, and uploading ten of them is the slow part of saving.
    for (final bytes in returned!) {
      expect(bytes.sublist(0, 2), [0xFF, 0xD8]);
    }
  });
}
