import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/chat_screen.dart';
import '../features/models/active_models_screen.dart';
import '../features/models/custom_catalogue_screen.dart';
import '../features/models/model_details_screen.dart';
import '../features/models/models_screen.dart';
import '../features/providers/providers_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/chat',
    routes: [
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(
        path: '/models',
        builder: (context, state) => const ModelsScreen(),
      ),
      GoRoute(
        path: '/models/active',
        builder: (context, state) => const ActiveModelsScreen(),
      ),
      GoRoute(
        path: '/models/custom',
        builder: (context, state) => const CustomCatalogueScreen(),
      ),
      GoRoute(
        path: '/models/details',
        builder: (context, state) =>
            ModelDetailsScreen(modelId: state.uri.queryParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/providers',
        builder: (context, state) => const ProvidersScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
