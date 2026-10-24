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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchKrithaPalette(context);
    final runtime = ref.watch(runtimeStatusProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1, -1.1),
            radius: 1.2,
            colors: [
              Color(0x1A22D3EE),
              KrithaColors.bgBase.withValues(alpha: 0),
            ],
            stops: [0, 0.65],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _SettingsHeader(onBack: () => context.pop()),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _SectionLabel('VOICE'),
                    _WakeWordControl(),
                    SizedBox(height: 22),
                    _SectionLabel('THEME'),
                    _ThemeControl(),
                    SizedBox(height: 22),
                    _SectionLabel('RUNTIME PROBES'),
                    _Card(
                      child: runtime.when(
                        data: (status) => _RuntimeRows(status: status),
                        loading: () => _LoadingProbe(),
                        error: (error, stackTrace) => _ProbeError(error: error),
                      ),
                    ),
                    SizedBox(height: 22),
                    _SectionLabel('PERSISTENCE'),
                    _Card(
                      child: Column(
                        children: [
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedHardDrive,
                            label: 'Drift database',
                            value: 'kritha.sqlite',
                            ok: true,
                          ),
                          _RowDivider(),
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
                          _RowDivider(),
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
                    SizedBox(height: 22),
                    _SectionLabel('AUDIO & SPEECH'),
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
                          _RowDivider(),
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
                          _RowDivider(),
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedMic01,
                            label: 'Microphone permission',
                            value: runtime.value?.microphone ?? 'checking…',
                            ok: runtime.value?.microphone == 'granted',
                          ),
                          _RowDivider(),
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
                          _RowDivider(),
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
                    SizedBox(height: 22),
                    _SectionLabel('NETWORK & FILES'),
                    _Card(
                      child: Column(
                        children: [
                          _StatusRow(
                            icon: HugeIcons.strokeRoundedActivity01,
                            label: 'Dio HTTP client',
                            value: runtime.value?.dioBaseUrl ?? 'configured',
                            ok: true,
                          ),
                          _RowDivider(),
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
                    SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(chatControllerProvider.notifier)
                            .restart();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Local history re-seeded')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KrithaColors.textSecondary,
                        side: BorderSide(color: KrithaColors.borderStrong),
                        minimumSize: Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            KrithaRadius.base,
                          ),
                        ),
                      ),
                      icon: KrithaIcon(
                        icon: HugeIcons.strokeRoundedRotateCcw,
                        size: 16,
                      ),
                      label: Text('Reset local history'),
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Kritha',
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

class _ThemeControl extends ConsumerWidget {
  const _ThemeControl();

  static const _options = [
    (KrithaThemePreference.system, 'System Default', 'Follow the device theme'),
    (KrithaThemePreference.light, 'Light', 'Always use the light theme'),
    (KrithaThemePreference.dark, 'Dark', 'Always use the dark theme'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themePreferenceProvider);
    return _Card(
      child: Column(
        children: [
          for (final option in _options)
            Material(
              color: Colors.transparent,
              child: RadioListTile<KrithaThemePreference>(
                value: option.$1,
                // ignore: deprecated_member_use
                groupValue: selected,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(themePreferenceProvider.notifier)
                        .setPreference(value);
                  }
                },
                title: Text(option.$2),
                subtitle: Text(
                  option.$3,
                  style: TextStyle(
                    color: KrithaColors.textMuted,
                    fontSize: KrithaText.sizeXs,
                  ),
                ),
                activeColor: KrithaColors.accentBlue,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
        ],
      ),
    );
  }
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
          KrithaIcon(
            icon: HugeIcons.strokeRoundedAudioLines,
            size: KrithaIcons.lg,
            color: KrithaColors.accentLightBlue,
          ),
          SizedBox(width: KrithaSpacing.s12),
          Expanded(
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
            SizedBox(
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
      padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          Tooltip(
            message: 'Back',
            child: Material(
              color: KrithaColors.bgSecondary,
              shape: CircleBorder(
                side: BorderSide(color: KrithaColors.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkResponse(
                onTap: onBack,
                customBorder: CircleBorder(),
                containedInkWell: true,
                child: SizedBox(
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: KrithaText.sizeLg,
                    fontWeight: FontWeight.w700,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 4, bottom: 8),
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
      padding: EdgeInsets.all(14),
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
        _RowDivider(),
        _StatusRow(
          icon: HugeIcons.strokeRoundedAudioLines,
          label: 'sherpa ONNX',
          value: status.sherpaReady
              ? 'v${status.sherpaVersion} / ONNX v${status.onnxRuntimeVersion}'
              : 'unavailable',
          ok: status.sherpaReady,
        ),
        _RowDivider(),
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
    return Padding(
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
      style: TextStyle(fontSize: KrithaText.sizeXs, color: KrithaColors.error),
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
      padding: EdgeInsets.symmetric(vertical: 7),
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
          SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: KrithaColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 8),
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
                SizedBox(width: 5),
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
    return Divider(height: 1, color: KrithaColors.borderFaint);
  }
}
