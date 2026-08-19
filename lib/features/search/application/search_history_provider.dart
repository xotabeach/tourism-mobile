import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

const _historyKeyPrefix = 'search_history.';
const searchHistoryMaxItems = 1;
const searchHistoryMaxChars = 80;

abstract class SearchHistoryStore {
  Future<List<String>> load(String ownerKey);
  Future<void> save(String ownerKey, List<String> items);
}

class SharedPrefsSearchHistoryStore implements SearchHistoryStore {
  @override
  Future<List<String>> load(String ownerKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_historyKeyPrefix$ownerKey') ?? const [];
  }

  @override
  Future<void> save(String ownerKey, List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_historyKeyPrefix$ownerKey', items);
  }
}

class MemorySearchHistoryStore implements SearchHistoryStore {
  final _items = <String, List<String>>{};

  @override
  Future<List<String>> load(String ownerKey) {
    return Future.value(List<String>.from(_items[ownerKey] ?? const []));
  }

  @override
  Future<void> save(String ownerKey, List<String> items) {
    _items[ownerKey] = List<String>.from(items);
    return Future.value();
  }
}

final searchHistoryStoreProvider = Provider<SearchHistoryStore>((ref) {
  return SharedPrefsSearchHistoryStore();
});

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryController, List<String>>((ref) {
      final session = ref.watch(sessionProvider);
      final owner = (session.userId?.trim().isNotEmpty ?? false)
          ? session.userId!
          : 'guest';
      return SearchHistoryController(
        store: ref.watch(searchHistoryStoreProvider),
        ownerKey: owner,
      );
    });

class SearchHistoryController extends StateNotifier<List<String>> {
  SearchHistoryController({required this.store, required this.ownerKey})
    : super(const []) {
    _loaded = _load();
  }

  final SearchHistoryStore store;
  final String ownerKey;
  late final Future<void> _loaded;

  Future<void> _load() async {
    final items = await store.load(ownerKey);
    if (!mounted) {
      return;
    }
    final next = _sanitizeAll(items);
    state = next;
    if (next.length != items.length) {
      await store.save(ownerKey, next);
    }
  }

  Future<void> record(String raw) async {
    await _loaded;
    if (!mounted) {
      return;
    }
    final value = _sanitize(raw);
    if (value == null) {
      return;
    }
    state = [value];
    await store.save(ownerKey, state);
  }

  List<String> _visible = const [];
  var _inSession = false;

  List<String> get visibleHistory => _visible;

  void beginSession() {
    if (!mounted || _inSession) {
      return;
    }
    _inSession = true;
    unawaited(_snapshotVisible());
  }

  Future<void> _snapshotVisible() async {
    await _loaded;
    if (!mounted || !_inSession) {
      return;
    }
    _visible = List<String>.unmodifiable(state);
    state = List<String>.of(state);
  }

  void endSession({String? lastQuery}) {
    if (!mounted || !_inSession) {
      return;
    }
    _inSession = false;
    _visible = const [];
    final value = _sanitize(lastQuery ?? '');
    unawaited(
      Future<void>.microtask(() async {
        await _loaded;
        if (!mounted) {
          return;
        }
        if (value != null) {
          state = [value];
          await store.save(ownerKey, state);
          return;
        }
        final trimmed = _sanitizeAll(state);
        if (trimmed.length != state.length) {
          state = trimmed;
          await store.save(ownerKey, trimmed);
        }
      }),
    );
  }

  static String? _sanitize(String raw) {
    final value = raw.trim();
    if (value.runes.length < 2 || value.length > searchHistoryMaxChars) {
      return null;
    }
    return value;
  }

  static List<String> _sanitizeAll(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in items) {
      final value = _sanitize(raw);
      if (value == null) {
        continue;
      }
      final key = value.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      out.add(value);
      if (out.length >= searchHistoryMaxItems) {
        break;
      }
    }
    return out;
  }
}
