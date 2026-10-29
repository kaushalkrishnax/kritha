import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import 'widgets/workspace_header.dart';

class CustomCatalogueScreen extends StatelessWidget {
  const CustomCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    watchKrithaPalette(context);
    return Scaffold(
      backgroundColor: KrithaColors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                WorkspaceHeader(
                  title: 'Custom catalogue',
                  onBack: () => context.go('/models'),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      KrithaSpacing.s16,
                      KrithaSpacing.s4,
                      KrithaSpacing.s16,
                      KrithaSpacing.s32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WorkspaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: KrithaSpacing.s10,
                                      vertical: KrithaSpacing.s4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: KrithaColors.accentCyanBg,
                                      borderRadius: BorderRadius.circular(
                                        KrithaRadius.full,
                                      ),
                                    ),
                                    child: Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: KrithaText.size2xs,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: KrithaColors.accentCyan,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: KrithaSpacing.s10),
                                  Expanded(
                                    child: Text(
                                      'Bring your own model catalogue',
                                      style: TextStyle(
                                        fontSize: KrithaText.sizeLg,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: KrithaSpacing.s12),
                              Text(
                                'Custom catalogue endpoints are not available '
                                'in this build. This screen explains the gated '
                                'feature only; no endpoint is configured or '
                                'contacted.',
                                style: TextStyle(
                                  fontSize: KrithaText.sizeSm,
                                  color: KrithaColors.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: KrithaSpacing.s16),
                        WorkspaceSectionTitle('Planned in Pro'),
                        WorkspaceCard(
                          child: Column(
                            children: [
                              _Feature(
                                icon: HugeIcons.strokeRoundedDatabase,
                                title: 'Custom catalogue endpoints',
                                description: 'Point Kritha at a catalogue service you control.',
                              ),
                              WorkspaceDivider(),
                              _Feature(
                                icon: HugeIcons.strokeRoundedShieldCheck,
                                title: 'Your own response schema',
                                description: 'Map repository metadata into the same discovery surface.',
                              ),
                              WorkspaceDivider(),
                              _Feature(
                                icon: HugeIcons.strokeRoundedLockKeyhole,
                                title: 'Scoped credentials',
                                description: 'Keep catalogue access separate from inference provider keys.',
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: KrithaSpacing.s20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  KrithaRadius.base,
                                ),
                              ),
                            ),
                            icon: KrithaIcon(
                              icon: HugeIcons.strokeRoundedSparkles,
                              size: 16,
                            ),
                            label: const Text('Available in Pro'),
                          ),
                        ),
                        SizedBox(height: KrithaSpacing.s8),
                        Text(
                          'Subscription and billing are out of scope for this '
                          'build.',
                          style: TextStyle(
                            fontSize: KrithaText.sizeXs,
                            color: KrithaColors.textDimmed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KrithaSpacing.s10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KrithaIcon(
            icon: icon,
            size: KrithaIcons.base,
            color: KrithaColors.accentLightBlue,
          ),
          SizedBox(width: KrithaSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: KrithaText.sizeSm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    color: KrithaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
