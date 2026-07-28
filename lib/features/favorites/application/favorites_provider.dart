import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tourism_mobile/core/config/app_config.dart';
import 'package:tourism_mobile/core/network/api_client.dart';
import 'package:tourism_mobile/features/favorites/data/favorites_repository_impl.dart';
import 'package:tourism_mobile/features/favorites/domain/favorites_repository.dart';
import 'package:tourism_mobile/features/onboarding/application/session_provider.dart';

class FavoritesState {
  const FavoritesState({
    this.placeIds = const {},
    this.routeIds = const {},
    this.isLoading = false,
  });

  final Set<String> placeIds;
  final Set<String> routeIds;
  final bool isLoading;

  FavoritesState copyWith({
    Set<String>? placeIds,
    Set<String>? routeIds,
    bool? isLoading,
  }) {
    return FavoritesState(
      placeIds: placeIds ?? this.placeIds,
      routeIds: routeIds ?? this.routeIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FavoritesController extends StateNotifier<FavoritesState> {
  FavoritesController(this._repository) : super(const FavoritesState());

  final FavoritesRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repository.list();
      state = FavoritesState(
        placeIds: result.placeIds,
        routeIds: result.routeIds,
      );
    } on Object {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> addRoute(String routeId) async {
    if (state.routeIds.contains(routeId)) {
      return;
    }
    final previous = state.routeIds;
    state = state.copyWith(routeIds: Set.unmodifiable({...previous, routeId}));
    try {
      await _repository.addRoute(routeId);
    } on Object {
      state = state.copyWith(routeIds: previous);
      rethrow;
    }
  }

  Future<void> removeRoute(String routeId) async {
    if (!state.routeIds.contains(routeId)) {
      return;
    }
    final previous = state.routeIds;
    state = state.copyWith(
      routeIds: Set.unmodifiable(previous.where((id) => id != routeId)),
    );
    try {
      await _repository.removeRoute(routeId);
    } on Object {
      state = state.copyWith(routeIds: previous);
      rethrow;
    }
  }

  Future<void> toggleRoute(String routeId) async {
    if (state.routeIds.contains(routeId)) {
      await removeRoute(routeId);
    } else {
      await addRoute(routeId);
    }
  }

  Future<void> addPlace(String placeId) async {
    if (state.placeIds.contains(placeId)) {
      return;
    }
    final previous = state.placeIds;
    state = state.copyWith(placeIds: Set.unmodifiable({...previous, placeId}));
    try {
      await _repository.addPlace(placeId);
    } on Object {
      state = state.copyWith(placeIds: previous);
      rethrow;
    }
  }

  Future<void> removePlace(String placeId) async {
    if (!state.placeIds.contains(placeId)) {
      return;
    }
    final previous = state.placeIds;
    state = state.copyWith(
      placeIds: Set.unmodifiable(previous.where((id) => id != placeId)),
    );
    try {
      await _repository.removePlace(placeId);
    } on Object {
      state = state.copyWith(placeIds: previous);
      rethrow;
    }
  }

  Future<void> clear() async {
    state = const FavoritesState();
  }
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMockData) {
    return InMemoryFavoritesRepository();
  }
  return ApiFavoritesRepository(ref.watch(dioProvider));
});

final favoritesProvider =
    StateNotifierProvider<FavoritesController, FavoritesState>((ref) {
      final config = ref.watch(appConfigProvider);
      final controller = FavoritesController(
        ref.watch(favoritesRepositoryProvider),
      );
      ref.listen<SessionState>(sessionProvider, (previous, next) {
        final becameAuthed =
            next.onboardingCompleted &&
            next.accessToken != null &&
            !(previous?.onboardingCompleted ?? false);
        if (becameAuthed && !config.useMockData) {
          unawaited(controller.refresh());
        }
        if (!next.onboardingCompleted &&
            (previous?.onboardingCompleted ?? false)) {
          unawaited(controller.clear());
        }
      });
      final session = ref.read(sessionProvider);
      if (session.onboardingCompleted && !config.useMockData) {
        unawaited(controller.refresh());
      }
      return controller;
    });

/// Back-compat for swipe deck / catalog that watched favorite route ids.
final favoriteRouteIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(favoritesProvider).routeIds;
});
