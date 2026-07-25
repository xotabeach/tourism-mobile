import 'package:flutter_riverpod/flutter_riverpod.dart';

class FavoriteRoutesController extends StateNotifier<Set<String>> {
  FavoriteRoutesController() : super(const {});

  void add(String routeId) {
    if (state.contains(routeId)) {
      return;
    }
    state = Set.unmodifiable({...state, routeId});
  }

  void remove(String routeId) {
    if (!state.contains(routeId)) {
      return;
    }
    state = Set.unmodifiable(state.where((id) => id != routeId));
  }

  void toggle(String routeId) {
    state.contains(routeId) ? remove(routeId) : add(routeId);
  }
}

final favoriteRouteIdsProvider =
    StateNotifierProvider<FavoriteRoutesController, Set<String>>((ref) {
      return FavoriteRoutesController();
    });
