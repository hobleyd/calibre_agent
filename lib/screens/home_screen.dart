import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/log_entry.dart';
import '../providers/server_provider.dart';
import '../providers/settings_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Row(
        children: [
          // Left panel — controls
          SizedBox(
            width: 380,
            child: Column(
              children: [
                _AppHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _ServerCard(),
                      SizedBox(height: 12),
                      _LibraryCard(),
                      SizedBox(height: 12),
                      _CertCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Divider
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          // Right panel — activity log
          const Expanded(child: _ActivityLog()),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            'Calibre Agent',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends ConsumerWidget {
  const _ServerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serverProvider);
    final notifier = ref.read(serverProvider.notifier);

    final (statusColor, statusLabel, statusIcon) = switch (state.status) {
      ServerStatus.running => (
          Colors.green,
          'Running',
          Icons.circle,
        ),
      ServerStatus.starting => (
          Colors.orange,
          'Starting…',
          Icons.circle,
        ),
      ServerStatus.error => (
          Colors.red,
          'Error',
          Icons.error_outline,
        ),
      ServerStatus.stopped => (
          Colors.grey,
          'Stopped',
          Icons.circle_outlined,
        ),
    };

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 8),
              Text(
                'Server',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
          if (state.serverUrl != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Clipboard.setData(
                  ClipboardData(text: state.serverUrl!)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.serverUrl!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontFamily: 'monospace',
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy_rounded,
                    size: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'mDNS: calibre-agent._http._tcp',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isStarting
                  ? null
                  : () async {
                      if (state.isRunning) {
                        await notifier.stop();
                      } else {
                        await notifier.start();
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: state.isRunning
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              child: state.isStarting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(state.isRunning ? 'Stop Server' : 'Start Server'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCard extends ConsumerWidget {
  const _LibraryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final state = ref.watch(serverProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Library',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  settings.libraryPath.isEmpty
                      ? 'Not configured'
                      : settings.libraryPath,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: settings.libraryPath.isEmpty
                            ? Theme.of(context).colorScheme.outline
                            : null,
                        fontFamily: 'monospace',
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: state.isRunning
                    ? null
                    : () async {
                        final result = await FilePicker.getDirectoryPath(
                          dialogTitle: 'Select Calibre Library',
                        );
                        if (result != null) {
                          await settingsNotifier.setLibraryPath(result);
                        }
                      },
                child: const Text('Browse'),
              ),
            ],
          ),
          if (state.bookCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  '${NumberFormat.decimalPattern().format(state.bookCount)} books',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          _PortRow(enabled: !state.isRunning),
        ],
      ),
    );
  }
}

class _PortRow extends ConsumerStatefulWidget {
  final bool enabled;

  const _PortRow({required this.enabled});

  @override
  ConsumerState<_PortRow> createState() => _PortRowState();
}

class _PortRowState extends ConsumerState<_PortRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final port = ref.read(settingsProvider).port;
    _controller = TextEditingController(text: port.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Port:', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            style: Theme.of(context).textTheme.bodySmall,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final port = int.tryParse(value);
              if (port != null && port > 0 && port < 65536) {
                ref.read(settingsProvider.notifier).setPort(port);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _CertCard extends ConsumerWidget {
  const _CertCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(serverProvider);
    final notifier = ref.read(serverProvider.notifier);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SSL Certificate',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Icon(
                Icons.lock_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Self-signed (managed)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.certExpiry != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expires: ${state.certExpiry}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: state.isRunning
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Regenerate Certificate?'),
                        content: const Text(
                          'A new self-signed certificate will be generated. '
                          'inkworm will need to re-accept it.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Regenerate'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) await notifier.regenerateCert();
                  },
            child: const Text('Regenerate Certificate'),
          ),
        ],
      ),
    );
  }
}

class _ActivityLog extends ConsumerWidget {
  const _ActivityLog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(serverProvider.select((s) => s.logEntries));
    final notifier = ref.read(serverProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
          child: Row(
            children: [
              Text(
                'Activity',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                TextButton(
                  onPressed: notifier.clearLog,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    'No activity yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return _LogRow(entry: entries[index]);
                  },
                ),
        ),
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;

  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(entry.timestamp);
    final color = switch (entry.level) {
      LogLevel.error => Colors.red,
      LogLevel.warning => Colors.orange,
      LogLevel.info => Theme.of(context).colorScheme.onSurface,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              timeStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
            ),
          ),
          if (entry.statusCode != null) ...[
            SizedBox(
              width: 36,
              child: Text(
                entry.statusCode.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: entry.statusCode! >= 400
                          ? Colors.orange
                          : Colors.green,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
              ),
            ),
          ],
          Expanded(
            child: Text(
              entry.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
