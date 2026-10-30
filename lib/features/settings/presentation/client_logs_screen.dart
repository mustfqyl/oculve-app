import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/models/vpn_state.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/server_latency.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/inline_feedback.dart';
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

/// Splits a recorded line into its ISO timestamp and message so the timestamp
/// can sit on its own quiet line. Both parts stay one selectable string, so
/// copying a line keeps the original text intact.
({String? stamp, String message}) diagnosticLineParts(String line) {
  final space = line.indexOf(' ');
  if (space <= 0) return (stamp: null, message: line);
  final head = line.substring(0, space);
  if (!_isoDatePrefix.hasMatch(head)) return (stamp: null, message: line);
  return (stamp: head, message: line.substring(space + 1));
}

final RegExp _isoDatePrefix = RegExp(r'^\d{4}-\d{2}-\d{2}T');

Color _foreground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppTheme.foreground
    : AppTheme.lightForeground;

Color _muted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppTheme.foregroundMuted
    : AppTheme.lightForegroundMuted;

class ClientLogsScreen extends ConsumerStatefulWidget {
  const ClientLogsScreen({super.key});

  @override
  ConsumerState<ClientLogsScreen> createState() => _ClientLogsScreenState();
}

class _ClientLogsScreenState extends ConsumerState<ClientLogsScreen> {
  late Future<NativeSnapshotResult> _nativeDiagnostics;
  final _error = InlineErrorController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _error.dispose();
    super.dispose();
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
        _error.show(
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
    final state = ref.watch(vpnProvider);
    final events = ref.read(vpnProvider.notifier).events;
    final pingDiagnostics = ref.watch(serverLatencyDiagnosticsProvider);
    final countStyle = TextStyle(
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: _muted(context),
    );
    return AppPage(
      title: 'Connection events',
      feedback: _error,
      action: IconButton(
        icon: Icon(
          Icons.refresh,
          semanticLabel: context.tr('Refresh diagnostics'),
        ),
        onPressed: () => setState(_refresh),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _ReportSummary(
            state: state,
            latestEvent: events.isEmpty ? null : events.last,
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 20),
          _SectionCard(
            title: 'App events',
            trailing: events.isEmpty
                ? null
                : Text('${events.length}', style: countStyle),
            initiallyExpanded: true,
            child: events.isEmpty
                ? const _EmptyLine('No connection attempts yet.')
                : _EventList(List.of(events)),
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'TCP ping checks',
            trailing: pingDiagnostics.isEmpty
                ? null
                : Text('${pingDiagnostics.length}', style: countStyle),
            child: pingDiagnostics.isEmpty
                ? const _EmptyLine('No server ping checks have been recorded.')
                : _DiagnosticLines(pingDiagnostics),
          ),
          const SizedBox(height: 10),
          _NativeDiagnosticsSection(future: _nativeDiagnostics),
        ],
      ),
    );
  }
}

/// One-glance answer first: current status and the most recent activity. The
/// raw sections below only add detail.
class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.state, required this.latestEvent});

  final VpnState state;
  final String? latestEvent;

  String _statusLabel(BuildContext context) => switch (state) {
    VpnState.connected => context.tr('Connected'),
    VpnState.connecting => context.tr('Connecting'),
    VpnState.disconnecting => context.tr('Disconnecting'),
    VpnState.error => context.tr('Error'),
    VpnState.disconnected => context.tr('Disconnected'),
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = _muted(context);
    final problem = state == VpnState.error;
    final dotColor = state == VpnState.connected
        ? AppTheme.successForeground(isDark: dark)
        : problem
        ? AppTheme.warningColor
        : muted;
    final captionStyle = TextStyle(
      fontSize: 10,
      height: 1.25,
      letterSpacing: 1,
      fontWeight: FontWeight.w600,
      color: muted,
    );
    return FrostedCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: captionStyle),
                    const SizedBox(height: 3),
                    Text(
                      _statusLabel(context),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: problem
                            ? AppTheme.warningColor
                            : _foreground(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: muted.withValues(alpha: .16)),
          const SizedBox(height: 12),
          Text('Latest activity', style: captionStyle),
          const SizedBox(height: 6),
          if (latestEvent == null)
            const _EmptyLine('No connection attempts yet.')
          else
            _EventText(latestEvent!),
        ],
      ),
    );
  }
}

/// A calm card whose technical body stays folded until the reader asks for it.
class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = _muted(context);
    return FrostedCard(
      padding: EdgeInsets.zero,
      borderRadius: 14,
      color: dark ? Colors.white.withValues(alpha: .055) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(14),
              overlayColor: AppTheme.interactionOverlay(isDark: dark),
              splashFactory: NoSplash.splashFactory,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        flex: 3,
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: _foreground(context),
                          ),
                        ),
                      ),
                      if (widget.trailing != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: widget.trailing,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

/// Newest first, with a short preview so a long history never buries the page.
class _EventList extends StatefulWidget {
  const _EventList(this.events);

  final List<String> events;

  @override
  State<_EventList> createState() => _EventListState();
}

class _EventListState extends State<_EventList> {
  static const _previewCount = 6;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final newestFirst = widget.events.reversed.toList();
    final visible = _showAll
        ? newestFirst
        : newestFirst.take(_previewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _EventText(visible[i]),
        ],
        if (newestFirst.length > _previewCount) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: _foreground(context),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(_showAll ? 'Show fewer' : 'Show all'),
            ),
          ),
        ],
      ],
    );
  }
}

class _EventText extends StatelessWidget {
  const _EventText(this.event);

  final String event;

  @override
  Widget build(BuildContext context) {
    final parts = diagnosticLineParts(event);
    return SelectableText.rich(
      TextSpan(
        children: [
          if (parts.stamp != null)
            TextSpan(
              text: '${parts.stamp}\n',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                color: _muted(context),
              ),
            ),
          TextSpan(
            text: parts.message,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: _foreground(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticLines extends StatelessWidget {
  const _DiagnosticLines(this.lines);

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < lines.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        SelectableText(
          lines[i],
          style: TextStyle(fontSize: 11.5, height: 1.5, color: _muted(context)),
        ),
      ],
    ],
  );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 12, height: 1.45, color: _muted(context)),
  );
}

class _NativeDiagnosticsSection extends StatelessWidget {
  const _NativeDiagnosticsSection({required this.future});

  final Future<NativeSnapshotResult> future;

  @override
  Widget build(BuildContext context) {
    final muted = _muted(context);
    return FutureBuilder<NativeSnapshotResult>(
      future: future,
      builder: (context, snapshot) {
        final result = snapshot.data;
        final failed = result != null && !result.succeeded;
        final empty =
            result != null && result.succeeded && result.text.trim().isEmpty;
        return _SectionCard(
          title: 'Xray diagnostics',
          trailing: result == null
              ? null
              : Text(
                  failed
                      ? 'Not available'
                      : empty
                      ? 'No records'
                      : 'Available',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: failed ? AppTheme.warningColor : muted,
                  ),
                ),
          child: result == null
              ? const LinearProgressIndicator(minHeight: 2)
              : SelectableText(
                  nativeDiagnosticsDisplayText(result),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: failed ? AppTheme.warningColor : muted,
                  ),
                ),
        );
      },
    );
  }
}
