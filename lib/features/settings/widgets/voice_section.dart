import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme.dart';
import '../../../services/tts_settings.dart';
import '../../../services/wake_word_bridge.dart';
import '../../../services/wake_word_controller.dart';
import 'settings_primitives.dart';

class WakeWordControl extends ConsumerStatefulWidget {
  const WakeWordControl({super.key});

  @override
  ConsumerState<WakeWordControl> createState() => _WakeWordControlState();
}

class _WakeWordControlState extends ConsumerState<WakeWordControl> {
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
        if (!await WakeWordBridge.canDrawOverlays()) {
          await WakeWordBridge.requestOverlayPermission();
        }
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
    final mode = ref.watch(wakeWordModeProvider);
    return SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          SizedBox(height: KrithaSpacing.s12),
          const SettingsRowDivider(),
          SizedBox(height: KrithaSpacing.s12),
          Text(
            'On wake word',
            style: TextStyle(
              fontSize: KrithaText.sizeXs,
              fontWeight: FontWeight.w600,
              color: KrithaColors.textSecondary,
            ),
          ),
          SizedBox(height: KrithaSpacing.s8),
          SegmentedButton<WakeWordMode>(
            segments: [
              for (final item in WakeWordMode.values)
                ButtonSegment<WakeWordMode>(
                  value: item,
                  label: Text(item.label),
                ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              ref.read(wakeWordModeProvider.notifier).setMode(selection.first);
            },
          ),
          SizedBox(height: KrithaSpacing.s6),
          Text(
            mode.description,
            style: TextStyle(
              color: KrithaColors.textMuted,
              fontSize: KrithaText.sizeXs,
            ),
          ),
        ],
      ),
    );
  }
}

class DefaultAssistantControl extends StatefulWidget {
  const DefaultAssistantControl({super.key});

  @override
  State<DefaultAssistantControl> createState() =>
      _DefaultAssistantControlState();
}

class _DefaultAssistantControlState extends State<DefaultAssistantControl>
    with WidgetsBindingObserver {
  bool _isDefault = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final isDefault = await WakeWordBridge.isDefaultAssistant();
    if (!mounted) return;
    setState(() {
      _isDefault = isDefault;
      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    final opened = await WakeWordBridge.openAssistantSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open Default Assistant settings on this device.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(KrithaRadius.sm),
          onTap: _openSettings,
          child: Row(
            children: [
              KrithaIcon(
                icon: HugeIcons.strokeRoundedSparkles,
                size: KrithaIcons.lg,
                color: KrithaColors.accentLightBlue,
              ),
              SizedBox(width: KrithaSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Default Assistant'),
                    SizedBox(height: 3),
                    Text(
                      _isDefault
                          ? 'Kritha responds to system assistant gestures.'
                          : 'Set Kritha as your device digital assistant app.',
                      style: TextStyle(
                        color: KrithaColors.textMuted,
                        fontSize: KrithaText.sizeXs,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: KrithaSpacing.s8),
              if (_loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  _isDefault ? 'Active' : 'Not set',
                  style: TextStyle(
                    fontSize: KrithaText.sizeXs,
                    fontWeight: FontWeight.w600,
                    color: _isDefault
                        ? KrithaColors.success
                        : KrithaColors.textMuted,
                  ),
                ),
              SizedBox(width: KrithaSpacing.s6),
              KrithaIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: KrithaColors.textDimmed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TtsSettingsControl extends ConsumerWidget {
  const TtsSettingsControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(ttsSettingsProvider);
    final controller = ref.read(ttsSettingsProvider.notifier);
    return SettingsCard(
      child: Column(
        children: [
          SettingsToggleRow(
            icon: HugeIcons.strokeRoundedAudioLines,
            label: 'TTS streaming',
            description:
                'Splits replies into sentences and synthesizes the next one '
                'while the current sentence plays.',
            value: settings.streaming,
            onChanged: controller.setStreaming,
          ),
          const SettingsRowDivider(),
          SettingsToggleRow(
            icon: HugeIcons.strokeRoundedDatabase,
            label: 'TTS caching',
            description:
                'Reuses synthesized audio in memory until the app closes.',
            value: settings.caching,
            onChanged: controller.setCaching,
          ),
        ],
      ),
    );
  }
}
