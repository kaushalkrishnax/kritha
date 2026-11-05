import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'active_models_content.dart';
import 'models_workspace_scaffold.dart';
import 'provider_models_content.dart';

/// Unified Models workspace; destinations swap below a stable header.
class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key, required this.destination});

  final ModelsWorkspaceDestination destination;

  @override
  Widget build(BuildContext context) {
    return ModelsWorkspaceScaffold(
      destination: destination,
      onDestinationSelected: (next) {
        if (next == destination) return;
        context.replace(next.location);
      },
      child: destination == ModelsWorkspaceDestination.active
          ? const ActiveModelsContent()
          : const ProviderModelsContent(),
    );
  }
}
