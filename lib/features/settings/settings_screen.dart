import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../services/runtime_probe.dart';
import '../../services/wake_word_bridge.dart';
import '../chat/chat_controller.dart';
import '../chat/widgets/kritha_avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeStatusProvider);
    final messageCount =
        ref.watch(chatControllerProvider).value?.messages.length ?? 0;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1, -1.1),
            radius: 1.2,
            colors: [Color(0x1A22D3EE), Color(0x000B0D10)],
            stops: [0, 0.65],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _SettingsHeader(onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    const _HeroCard(),
                    const SizedBox(height: 22),
                    const _SectionLabel('VOICE'),
                    const _WakeWordControl(),
                    const SizedBox(height: 22),
                    const _SectionLabel('RUNTIME PROBES'),
                    _Card(
                      child: runtime.when(
                        data: (status) => _RuntimeRows(status: status),
                        loading: () => const _LoadingProbe(),
                        error: (error, stackTrace) => _ProbeError(error: error),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('PERSISTENCE'),
                    _Card(
                      child: Column(
                        children: [
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedDatabase,
                            label: 'SQLite messages',
                            value: '$messageCount rows',
                            ok: true,
                          ),
                          const _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedHardDrive,
                            label: 'Drift database',
                            value: 'kritha.sqlite',
                            ok: true,
                          ),
                          const _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedLockKeyhole,
                            label: 'Secure storage',
                            value: switch (runtime.value) {
                              final status? =>
                                status.secureStorageReady
                                    ? 'encrypted probe ok'
                                    : 'unavailable',
                              null => 'checking…',
                            },
                            ok: runtime.value?.secureStorageReady,
                          ),
                          const _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedShieldCheck,
                            label: 'Shared preferences',
                            value: switch (runtime.value) {
                              final status? =>
                                status.preferencesReady
                                    ? 'write verified'
                                    : 'unavailable',
                              null => 'checking…',
                            },
                            ok: runtime.value?.preferencesReady,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('AUDIO & SPEECH'),
                    _Card(
                      child: Column(
                        children: [
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedCpu,
                            label: 'LiteRT-LM',
                            value: switch (runtime.value) {
                              final status? =>
                                status.liteRtLmReady
                                    ? 'native runtime ready; model not loaded'
                                    : 'unavailable',
                              null => 'checking…',
                            },
                            ok: runtime.value?.liteRtLmReady,
                          ),
                          const _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedAudioLines,
                            label: 'sherpa ONNX',
                            value: switch (runtime.value) {
                              final status? =>
                                status.sherpaReady
                                    ? 'v${status.sherpaVersion}'
                                    : 'unavailable',
                              null => 'checking…',
                            },
                            ok: runtime.value?.sherpaReady,
                          ),
                          const _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedMic01,
                            label: 'Microphone permission',
                            value: runtime.value?.microphone ?? 'checking…',
                            ok: runtime.value?.microphone == 'granted',
                          ),
                          const _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedActivity01,
                            label: 'Voice recorder',
                            value: switch (runtime.value) {
                              final status? =>
                                status.recorderReady
                                    ? 'record ready'
                                    : 'awaiting permission',
                              null => 'checking…',
                            },
                            ok: runtime.value?.recorderReady,
                          ),
                          const _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedPlay,
                            label: 'Audio playback',
                            value: switch (runtime.value) {
                              final status? =>
                                status.audioPlayerReady
                                    ? 'just_audio ready'
                                    : 'unavailable',
                              null => 'checking…',
                            },
                            ok: runtime.value?.audioPlayerReady,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('NETWORK & FILES'),
                    _Card(
                      child: Column(
                        children: [
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedActivity01,
                            label: 'Dio HTTP client',
                            value: runtime.value?.dioBaseUrl ?? 'configured',
                            ok: true,
                          ),
                          const _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedHardDrive,
                            label: 'Documents directory',
                            value: runtime.value?.documentsPath ?? 'checking…',
                            ok: (runtime.value?.documentsPath ?? '').isNotEmpty,
                            mono: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('PACKAGES IN THIS BUILD'),
                    const _Card(child: _PackageChips()),
                    const SizedBox(height: 22),
                    const _SectionLabel('MEASUREMENT'),
                    const _Card(child: _MeasurementNote()),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(chatControllerProvider.notifier)
                            .restart();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Local history re-seeded'),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KrithaColors.textSecondary,
                        side: const BorderSide(
                          color: KrithaColors.borderStrong,
                        ),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            KrithaRadius.base,
                          ),
                        ),
                      ),
                      icon: const KrithaIcon(
                        icon: HugeIcons.strokeRoundedRotateCcw,
                        size: 16,
                      ),
                      label: const Text('Reset local history'),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Kritha · v1.0.0+100',
                        style: TextStyle(
                          fontSize: KrithaText.size2xs,
                          color: KrithaColors.textDimmed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WakeWordControl extends StatefulWidget {
  const _WakeWordControl();

  @override
  State<_WakeWordControl> createState() => _WakeWordControlState();
}

class _WakeWordControlState extends State<_WakeWordControl> {
  static const _preferenceKey = 'kritha.wake_word.enabled';

  bool _available = false;
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final wanted = preferences.getBool(_preferenceKey) ?? false;
    final available = await WakeWordBridge.isAvailable();
    var running = await WakeWordBridge.isRunning();

    if (wanted && available && !running) {
      final microphone = await Permission.microphone.status;
      final notifications = await Permission.notification.status;
      if (microphone.isGranted && notifications.isGranted) {
        try {
          await WakeWordBridge.start();
          running = true;
        } on Object {
          running = false;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = running && wanted;
      _loading = false;
    });
    if (wanted && !running) {
      await preferences.setBool(_preferenceKey, false);
    }
  }

  Future<void> _toggle(bool enabled) async {
    setState(() => _loading = true);
    final preferences = await SharedPreferences.getInstance();
    try {
      if (enabled) {
        if (!await WakeWordBridge.isAvailable()) {
          throw PlatformException(
            code: 'WAKEWORD_MODEL_UNAVAILABLE',
            message:
                'Wake-word detection is not available in this Android build.',
          );
        }
        final microphone = await Permission.microphone.request();
        if (!microphone.isGranted) {
          throw PlatformException(
            code: 'MIC_PERMISSION_REQUIRED',
            message: 'Allow microphone access to enable wake-word detection.',
          );
        }
        final notifications = await Permission.notification.request();
        if (!notifications.isGranted) {
          throw PlatformException(
            code: 'NOTIFICATION_PERMISSION_REQUIRED',
            message:
                'Allow notifications for the persistent listening control.',
          );
        }
        await WakeWordBridge.start();
      } else {
        await WakeWordBridge.stop();
      }
      await preferences.setBool(_preferenceKey, enabled);
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _available = true;
        _loading = false;
      });
    } on Object catch (error) {
      await preferences.setBool(_preferenceKey, false);
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change wake-word setting: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          const KrithaIcon(
            icon: HugeIcons.strokeRoundedAudioLines,
            size: KrithaIcons.lg,
            color: KrithaColors.accentLightBlue,
          ),
          const SizedBox(width: KrithaSpacing.s12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hey Kritha wake word'),
                SizedBox(height: 3),
                Text(
                  'Listens in the background while the service is enabled.',
                  style: TextStyle(
                    color: KrithaColors.textMuted,
                    fontSize: KrithaText.sizeXs,
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(value: _enabled, onChanged: _available ? _toggle : null),
        ],
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          Tooltip(
            message: 'Back',
            child: Material(
              color: KrithaColors.bgSecondary,
              shape: const CircleBorder(
                side: BorderSide(color: KrithaColors.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkResponse(
                onTap: onBack,
                customBorder: const CircleBorder(),
                containedInkWell: true,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: KrithaIcon(
                    icon: HugeIcons.strokeRoundedChevronLeft,
                    size: 20,
                    color: KrithaColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Runtime & packages',
                  style: TextStyle(
                    fontSize: KrithaText.sizeLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'What the measured APK actually contains',
                  style: TextStyle(
                    fontSize: KrithaText.size2xs,
                    color: KrithaColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KrithaColors.bgSecondary,
              borderRadius: BorderRadius.circular(KrithaRadius.full),
              border: Border.all(color: KrithaColors.borderSubtle),
            ),
            child: const Text(
              'arm64-v8a',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: KrithaColors.accentCyan,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16233B), Color(0xFF10151D)],
        ),
        borderRadius: BorderRadius.circular(KrithaRadius.lg),
        border: Border.all(color: const Color(0x332563EB)),
      ),
      child: Row(
        children: [
          const KrithaAvatar(size: 54),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kritha Flutter stack',
                  style: TextStyle(
                    fontSize: KrithaText.sizeMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Release size probe for chat, persistence, Markdown and '
                  'the on-device speech runtime.',
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    height: 1.35,
                    color: KrithaColors.textMuted,
                  ),
                ),
                SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(label: 'release'),
                    _Chip(label: 'ARM64 only'),
                    _Chip(label: 'no models'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KrithaColors.bgBase.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(KrithaRadius.full),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: KrithaColors.accentLightBlue,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: KrithaText.label),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KrithaColors.bgSurface,
        borderRadius: BorderRadius.circular(KrithaRadius.md),
        border: Border.all(color: KrithaColors.borderSubtle),
      ),
      child: child,
    );
  }
}

class _RuntimeRows extends StatelessWidget {
  const _RuntimeRows({required this.status});

  final RuntimeStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(
          icon: HugeIcons.strokeRoundedCpu,
          label: 'LiteRT-LM',
          value: status.liteRtLmReady ? 'native runtime ready' : 'unavailable',
          ok: status.liteRtLmReady,
        ),
        const _RowDivider(),
        _StatusRow(
          icon: HugeIcons.strokeRoundedAudioLines,
          label: 'sherpa ONNX',
          value: status.sherpaReady
              ? 'v${status.sherpaVersion} / ONNX v${status.onnxRuntimeVersion}'
              : 'unavailable',
          ok: status.sherpaReady,
        ),
        const _RowDivider(),
        _StatusRow(
          icon: HugeIcons.strokeRoundedDatabase,
          label: 'SQLite',
          value: status.sqliteVersion.isEmpty
              ? 'unavailable'
              : 'v${status.sqliteVersion}',
          ok: status.sqliteVersion.isNotEmpty,
        ),
      ],
    );
  }
}

class _LoadingProbe extends StatelessWidget {
  const _LoadingProbe();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: KrithaColors.accentLightBlue,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Initialising platform packages…',
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              color: KrithaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProbeError extends StatelessWidget {
  const _ProbeError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Runtime probe failed: $error',
      style: const TextStyle(
        fontSize: KrithaText.sizeXs,
        color: KrithaColors.error,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    this.mono = false,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final bool? ok;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final color = switch (ok) {
      true => KrithaColors.success,
      false => KrithaColors.warning,
      null => KrithaColors.textDimmed,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: KrithaColors.bgPrimary,
              borderRadius: BorderRadius.circular(KrithaRadius.sm),
              border: Border.all(color: KrithaColors.borderFaint),
            ),
            child: KrithaIcon(
              icon: icon,
              size: 15,
              color: KrithaColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: KrithaColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: mono ? 10.5 : 11.5,
                      fontFamily: mono ? 'monospace' : null,
                      color: KrithaColors.textMuted,
                    ),
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

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: KrithaColors.borderFaint);
  }
}

class _PackageChips extends StatelessWidget {
  const _PackageChips();

  static const _packages = [
    'gpt_markdown 1.4.0',
    'flutter_riverpod 3.4.3',
    'go_router 18.1.1',
    'drift 2.35.2',
    'sqlite3 3.7.1',
    'flutter_secure_storage 11.2.0',
    'shared_preferences 2.5.6',
    'dio 5.11.1',
    'path_provider 2.1.6',
    'freezed 4.0.3',
    'json_serializable 6.15.2',
    'hugeicons 1.2.0',
    'litertlm 0.0.14',
    'sherpa_onnx 1.13.8',
    'record 7.1.2',
    'just_audio 0.10.6',
    'permission_handler 13.0.2',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final package in _packages)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: KrithaColors.bgPrimary,
              borderRadius: BorderRadius.circular(KrithaRadius.sm),
              border: Border.all(color: KrithaColors.borderFaint),
            ),
            child: Text(
              package,
              style: const TextStyle(
                fontSize: 10.5,
                color: KrithaColors.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }
}

class _MeasurementNote extends StatelessWidget {
  const _MeasurementNote();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The release APK is built for android-arm64 and inspected after '
          'build. No tree-shaking flags are disabled and no unused code is '
          'linked in to inflate the result.',
          style: TextStyle(
            fontSize: KrithaText.sizeXs,
            height: 1.45,
            color: KrithaColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: KrithaColors.bgDeepest,
            borderRadius: BorderRadius.circular(KrithaRadius.sm),
            border: Border.all(color: KrithaColors.borderSubtle),
          ),
          child: const Text(
            'flutter build apk --release \\\n'
            '  --target-platform=android-arm64 \\\n'
            '  --analyze-size',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: KrithaColors.accentSky,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            KrithaIcon(
              icon: HugeIcons.strokeRoundedInfo,
              size: 13,
              color: KrithaColors.warning,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Wake-word inference ships in the base APK. LiteRT-LM and '
                'sherpa ONNX are delivered together as an on-demand split; '
                'model weights are separate.',
                style: TextStyle(
                  fontSize: KrithaText.size2xs,
                  color: KrithaColors.textDimmed,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
