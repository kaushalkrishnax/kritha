import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalogue_failure.dart';
import 'catalogue_filter.dart';
import 'catalogue_model.dart';
import 'catalogue_providers.dart';

class CatalogueState {
  const CatalogueState({
    this.query = '',
    this.capability,
    this.sort = CatalogueSort.trending,
    this.filters = CatalogueFilterPresets.defaults,
    this.models = const [],
    this.nextCursor,
    this.loading = false,
    this.loadingMore = false,
    this.hasLoaded = false,
    this.failure,
    this.loadMoreFailure,
  });

  final String query;
  final ModelCapability? capability;
  final CatalogueSort sort;
  final List<CatalogueFilter> filters;
  final List<CatalogueModel> models;
  final String? nextCursor;
  final bool loading;
  final bool loadingMore;
  final bool hasLoaded;
  final CatalogueFailure? failure;
  final CatalogueFailure? loadMoreFailure;

  bool get isIdle =>
      query.trim().isEmpty &&
      capability == null &&
      sort == CatalogueSort.trending;
  bool get hasMore => nextCursor != null;

  CatalogueState copyWith({
    String? query,
    ModelCapability? capability,
    CatalogueSort? sort,
    List<CatalogueFilter>? filters,
    List<CatalogueModel>? models,
    String? nextCursor,
    bool? loading,
    bool? loadingMore,
    bool? hasLoaded,
    CatalogueFailure? failure,
    CatalogueFailure? loadMoreFailure,
    bool clearCapability = false,
    bool clearCursor = false,
    bool clearFailure = false,
    bool clearLoadMoreFailure = false,
  }) {
    return CatalogueState(
      query: query ?? this.query,
      capability: clearCapability ? null : (capability ?? this.capability),
      sort: sort ?? this.sort,
      filters: filters ?? this.filters,
      models: models ?? this.models,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: clearFailure ? null : (failure ?? this.failure),
      loadMoreFailure: clearLoadMoreFailure
          ? null
          : (loadMoreFailure ?? this.loadMoreFailure),
    );
  }
}

class CatalogueController extends Notifier<CatalogueState> {
  static const _pageSize = 24;

  CancelToken? _cancel;
  int _revision = 0;

  @override
  CatalogueState build() {
    ref.onDispose(() {
      _cancel?.cancel();
      _cancel = null;
    });
    return const CatalogueState();
  }

  Future<void> search({
    String? query,
    ModelCapability? capability,
    bool clearCapability = false,
    CatalogueSort? sort,
    List<CatalogueFilter>? filters,
  }) async {
    final current = state;
    final nextQuery = query ?? current.query;
    final nextCapability = clearCapability
        ? null
        : (capability ?? current.capability);
    final nextSort = sort ?? current.sort;
    final nextFilters = filters ?? current.filters;
    final revision = ++_revision;
    _cancel?.cancel();
    final cancel = CancelToken();
    _cancel = cancel;

    state = current.copyWith(
      query: nextQuery,
      capability: nextCapability,
      clearCapability: clearCapability,
      sort: nextSort,
      filters: nextFilters,
      models: const [],
      clearCursor: true,
      loading: true,
      loadingMore: false,
      hasLoaded: true,
      clearFailure: true,
      clearLoadMoreFailure: true,
    );

    try {
      final page = await ref
          .read(modelCatalogueProvider)
          .search(
            query: nextQuery,
            capability: nextCapability,
            sort: nextSort,
            filters: nextFilters,
            limit: nextSort.sortsByParameters ? 100 : _pageSize,
            cancelToken: cancel,
          );
      if (!ref.mounted || revision != _revision) return;
      state = state.copyWith(
        models: _orderModels(filterDiscoverableModels(page.models), nextSort),
        nextCursor: nextSort.sortsByParameters ? null : page.nextCursor,
        loading: false,
        hasLoaded: true,
        clearFailure: true,
      );
    } on CatalogueCancelled {
      // A newer search owns the state.
    } on CatalogueFailure catch (failure) {
      if (!ref.mounted || revision != _revision) return;
      state = state.copyWith(
        loading: false,
        hasLoaded: true,
        failure: failure,
        clearCursor: true,
      );
    } on Object {
      if (!ref.mounted || revision != _revision) return;
      state = state.copyWith(
        loading: false,
        hasLoaded: true,
        failure: const CatalogueFailure(
          kind: CatalogueFailureKind.unknown,
          message: 'The catalogue request failed unexpectedly.',
        ),
        clearCursor: true,
      );
    }
  }

  Future<void> retry() {
    final current = state;
    return search(
      query: current.query,
      capability: current.capability,
      clearCapability: current.capability == null,
      sort: current.sort,
      filters: current.filters,
    );
  }

  void reset() {
    _revision++;
    _cancel?.cancel();
    _cancel = null;
    state = const CatalogueState();
  }

  Future<void> loadMore() async {
    final current = state;
    final cursor = current.nextCursor;
    if (cursor == null ||
        current.loading ||
        current.loadingMore ||
        current.failure != null) {
      return;
    }
    final revision = _revision;
    final cancel = CancelToken();
    _cancel = cancel;
    state = current.copyWith(loadingMore: true, clearLoadMoreFailure: true);

    try {
      final page = await ref
          .read(modelCatalogueProvider)
          .search(
            query: current.query,
            capability: current.capability,
            sort: current.sort,
            filters: current.filters,
            limit: _pageSize,
            cursor: cursor,
            cancelToken: cancel,
          );
      if (!ref.mounted || revision != _revision) return;
      final seen = {for (final model in state.models) model.id};
      final appended = [
        ...state.models,
        for (final model in filterDiscoverableModels(page.models))
          if (seen.add(model.id)) model,
      ];
      state = state.copyWith(
        models: _orderModels(appended, current.sort),
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        loadingMore: false,
        clearLoadMoreFailure: true,
      );
    } on CatalogueCancelled {
      // A new search or a newer page owns the state.
    } on CatalogueFailure catch (failure) {
      if (!ref.mounted || revision != _revision) return;
      state = state.copyWith(loadingMore: false, loadMoreFailure: failure);
    } on Object {
      if (!ref.mounted || revision != _revision) return;
      state = state.copyWith(
        loadingMore: false,
        loadMoreFailure: const CatalogueFailure(
          kind: CatalogueFailureKind.unknown,
          message: 'The next page could not be loaded.',
        ),
      );
    }
  }
}

List<CatalogueModel> _orderModels(
  List<CatalogueModel> models,
  CatalogueSort sort,
) {
  if (!sort.sortsByParameters) return models;
  final descending = sort == CatalogueSort.mostParameters;
  final ordered = [...models]
    ..sort((a, b) {
      final left = a.parameterCount;
      final right = b.parameterCount;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return descending ? right.compareTo(left) : left.compareTo(right);
    });
  return List.unmodifiable(ordered);
}

final catalogueProvider = NotifierProvider<CatalogueController, CatalogueState>(
  CatalogueController.new,
);

final modelDetailsProvider = FutureProvider.autoDispose
    .family<ModelDetails, String>((ref, id) {
      return ref.watch(modelCatalogueProvider).details(id);
    });
