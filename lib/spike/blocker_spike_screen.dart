import 'dart:async';

import 'package:flutter/material.dart';

import '../platform/blocker.dart';

/// Temporary screen for the M5 blocking spike. Replaced by the real UI in M3.
class BlockerSpikeScreen extends StatefulWidget {
  const BlockerSpikeScreen({super.key, required this.blocker});

  final AppBlocker blocker;

  @override
  State<BlockerSpikeScreen> createState() => _BlockerSpikeScreenState();
}

class _BlockerSpikeScreenState extends State<BlockerSpikeScreen>
    with WidgetsBindingObserver {
  BlockerStatus? _status;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await widget.blocker.status();
    if (mounted) setState(() => _status = s);
  }

  String _fmt(DateTime? t) => t == null
      ? '-'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  String _remaining(BlockerStatus s) {
    if (!s.locked || s.lockEndsAt == null) return 'none';
    final d = s.lockEndsAt!.difference(DateTime.now());
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 14);
    return Scaffold(
      appBar: AppBar(title: const Text('Blocking spike (M5)')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  s.serviceEnabled
                      ? 'Blocker service: ENABLED'
                      : 'Blocker service: OFF',
                  style: mono.copyWith(
                    fontSize: 18,
                    color: s.serviceEnabled
                        ? Colors.lightBlueAccent
                        : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Lock remaining: ${_remaining(s)}', style: mono),
                Text(
                  'Service connected at: ${_fmt(s.lastConnectedAt)}',
                  style: mono,
                ),
                Text(
                  'Service unbound at: ${_fmt(s.lastDisconnectedAt)}',
                  style: mono,
                ),
                Text('Blocks so far: ${s.blockCount}', style: mono),
                Text(
                  'Last blocked: ${s.lastBlockedPackage ?? '-'} at ${_fmt(s.lastBlockAt)}',
                  style: mono,
                ),
                Text('Emergency stops: ${s.emergencyStops}', style: mono),
                const Divider(height: 32),
                FilledButton(
                  onPressed: widget.blocker.openAccessibilitySettings,
                  child: const Text('1. Open Accessibility settings'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.blocker.openAppSettings,
                  child: const Text('App info (restricted settings, battery)'),
                ),
                const Divider(height: 32),
                FilledButton(
                  onPressed: () async {
                    await widget.blocker.startLock(const Duration(minutes: 2));
                    _refresh();
                  },
                  child: const Text('Start 2-minute test lock'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    await widget.blocker.startLock(const Duration(minutes: 45));
                    _refresh();
                  },
                  child: const Text('Start 45-minute survival lock'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  onPressed: () async {
                    await widget.blocker.stopLock();
                    _refresh();
                  },
                  child: const Text('Stop lock now (escape)'),
                ),
              ],
            ),
    );
  }
}
