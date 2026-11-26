import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';
import '../../../services/runtime_probe.dart';
import 'settings_primitives.dart';

class RuntimeProbesSection extends StatelessWidget {
  const RuntimeProbesSection({super.key, required this.runtime});

  final AsyncValue<RuntimeStatus> runtime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionLabel('RUNTIME PROBES'),
        SettingsCard(
          child: runtime.when(
            data: (status) => _RuntimeRows(status: status),
            loading: () => const _LoadingProbe(),
            error: (error, _) => _ProbeError(error: error),
          ),
        ),
        SizedBox(height: 22),
        const SettingsSectionLabel('PERSISTENCE'),
        SettingsCard(
          child: Column(
            children: [
              const SettingsStatusRow(
                icon: HugeIcons.strokeRoundedHardDrive,
                label: 'Drift database',
                value: 'kritha.sqlite',
                ok: true,
              ),
              const SettingsRowDivider(),
              SettingsStatusRow(
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
              const SettingsRowDivider(),
              SettingsStatusRow(
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
        const SettingsSectionLabel('AUDIO & SPEECH'),
        SettingsCard(
          child: Column(
            children: [
              SettingsStatusRow(
                icon: HugeIcons.strokeRoundedCpu,
                label: 'LiteRT-LM',
                value: switch (runtime.value) {
                  final status? =>
                    status.liteRtLmReady ? 'runtime linked' : 'unavailable',
                  null => 'checking…',
                },
                ok: runtime.value?.liteRtLmReady,
              ),
              const SettingsRowDivider(),
              SettingsStatusRow(
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
              const SettingsRowDivider(),
              SettingsStatusRow(
                icon: HugeIcons.strokeRoundedMic01,
                label: 'Microphone permission',
                value: runtime.value?.microphone ?? 'checking…',
                ok: runtime.value?.microphone == 'granted',
              ),
              const SettingsRowDivider(),
              SettingsStatusRow(
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
              const SettingsRowDivider(),
              SettingsStatusRow(
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
        const SettingsSectionLabel('NETWORK & FILES'),
        SettingsCard(
          child: Column(
            children: [
              SettingsStatusRow(
                icon: HugeIcons.strokeRoundedActivity01,
                label: 'Dio HTTP client',
                value: runtime.value?.dioBaseUrl ?? 'configured',
                ok: true,
              ),
              const SettingsRowDivider(),
              SettingsStatusRow(
                icon: HugeIcons.strokeRoundedHardDrive,
                label: 'Documents directory',
                value: runtime.value?.documentsPath ?? 'checking…',
                ok: (runtime.value?.documentsPath ?? '').isNotEmpty,
                mono: true,
              ),
            ],
          ),
        ),
      ],
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
        SettingsStatusRow(
          icon: HugeIcons.strokeRoundedCpu,
          label: 'LiteRT-LM',
          value: status.liteRtLmReady ? 'runtime linked' : 'unavailable',
          ok: status.liteRtLmReady,
        ),
        const SettingsRowDivider(),
        SettingsStatusRow(
          icon: HugeIcons.strokeRoundedAudioLines,
          label: 'sherpa ONNX',
          value: status.sherpaReady
              ? 'v${status.sherpaVersion} / ONNX v${status.onnxRuntimeVersion}'
              : 'unavailable',
          ok: status.sherpaReady,
        ),
        const SettingsRowDivider(),
        SettingsStatusRow(
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
