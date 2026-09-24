import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/core/widgets/app_page.dart';

class ClientLogsScreen extends ConsumerStatefulWidget {
  const ClientLogsScreen({super.key});

  @override
  ConsumerState<ClientLogsScreen> createState() => _ClientLogsScreenState();
}

class _ClientLogsScreenState extends ConsumerState<ClientLogsScreen> {
  late Future<String> _nativeDiagnostics;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _nativeDiagnostics = () async {
      try {
        await ref.read(vpnProvider.notifier).initialize();
        return await VlessPlatform.instance.getProviderDebugSnapshot();
      } catch (_) {
        return '';
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(vpnProvider);
    final events = ref.read(vpnProvider.notifier).events;
    final pingDiagnostics = ref.watch(serverLatencyDiagnosticsProvider);
    return AppPage(
      title: 'Connection events',
      action: IconButton(
        tooltip: context.tr('Refresh diagnostics'),
        icon: const Icon(Icons.refresh),
        onPressed: () => setState(_refresh),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
          FutureBuilder<String>(
            future: _nativeDiagnostics,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              final diagnostics = snapshot.data!.trim();
              return SelectableText(
                diagnostics.isEmpty
                    ? 'No native diagnostics have been recorded.'
                    : diagnostics,
              );
            },
          ),
        ],
      ),
    );
  }
}
