import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_feedback.dart';
import 'package:oculve/core/connection/connection_preferences.dart';
import 'package:oculve/core/connection/diagnostic_report.dart';
import 'package:oculve/core/account/private_text_export.dart';

/// A native diagnostics snapshot plus whether retrieval itself succeeded, so
/// "snapshot unavailable" never renders the same as "snapshot empty".
class NativeSnapshotResult {
  const NativeSnapshotResult(this.text, this.succeeded);
  final String text;
  final bool succeeded;
}

/// The three diagnostics outcomes stay distinct: unavailable snapshot, empty
/// snapshot, and recorded diagnostics.
String nativeDiagnosticsDisplayText(NativeSnapshotResult result) {
  if (!result.succeeded) {
    return 'Native diagnostics could not be retrieved. '
        'Connect to the VPN once, then refresh.';
  }
  return result.text.trim().isEmpty
      ? 'No native diagnostics have been recorded.'
      : result.text.trim();
}

class ClientLogsScreen extends ConsumerStatefulWidget {
  const ClientLogsScreen({super.key});

  @override
  ConsumerState<ClientLogsScreen> createState() => _ClientLogsScreenState();
}

class _ClientLogsScreenState extends ConsumerState<ClientLogsScreen> {
  late Future<NativeSnapshotResult> _nativeDiagnostics;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _nativeDiagnostics = () async {
      try {
        await ref.read(vpnProvider.notifier).initialize();
        final snapshot = await VlessPlatform.instance
            .getProviderDebugSnapshot();
        return NativeSnapshotResult(snapshot, true);
      } catch (_) {
        return const NativeSnapshotResult('', false);
      }
    }();
  }

  bool _exporting = false;
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final options = await ConnectionPreferences.read();
      var snapshotSucceeded = true;
      final version = await VlessPlatform.instance
          .getCoreVersion()
          .timeout(const Duration(seconds: 3))
          .catchError((_) => 'Unavailable');
      final nativeDiagnostics = await VlessPlatform.instance
          .getProviderDebugSnapshot()
          .timeout(const Duration(seconds: 3))
          .catchError((_) {
            snapshotSucceeded = false;
            return '';
          });
      if (!mounted) return;
      final report = diagnosticReport(
        state: ref.read(vpnProvider).name,
        events: ref.read(vpnProvider.notifier).events,
        pingChecks: ref.read(serverLatencyDiagnosticsProvider).length,
        sharing: options.shareLan,
        reconnect: options.reconnect,
        coreVersion: version,
        nativeDiagnostics: nativeDiagnostics,
        nativeSnapshotSucceeded: snapshotSucceeded,
      );
      await exportPrivateText(
        context,
        fileName: 'oculve-diagnostics.txt',
        contents: report,
      );
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback: 'Could not save the troubleshooting report.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(vpnProvider);
    final events = ref.read(vpnProvider.notifier).events;
    final pingDiagnostics = ref.watch(serverLatencyDiagnosticsProvider);
    return AppPage(
      title: 'Connection events',
      action: IconButton(
        icon: Icon(
          Icons.refresh,
          semanticLabel: context.tr('Refresh diagnostics'),
        ),
        onPressed: () => setState(_refresh),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _exporting ? null : _export,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Export troubleshooting report',
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'APP EVENTS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty) const Text('No connection attempts yet.'),
          ...events.reversed.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(event),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'TCP PING CHECKS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (pingDiagnostics.isEmpty)
            const Text('No server ping checks have been recorded.'),
          ...pingDiagnostics.map(
            (diagnostic) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(diagnostic),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'XRAY DIAGNOSTICS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FutureBuilder<NativeSnapshotResult>(
            future: _nativeDiagnostics,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              return SelectableText(
                nativeDiagnosticsDisplayText(snapshot.data!),
              );
            },
          ),
        ],
      ),
    );
  }
}
