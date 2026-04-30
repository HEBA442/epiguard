import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/eeg/muse_ble_service.dart';
import '../../features/eeg/watch_ble_service.dart';
import '../../features/seizure/seizure_provider.dart';
import '../../features/seizure/seizure_detection_service.dart';
import '../../features/seizure/seizure_alert_widget.dart';


class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SeizureProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('EpiGuard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // Monitoring toggle button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: provider.museConnected
                ? TextButton.icon(
                    onPressed: provider.monitoringStatus ==
                            MonitoringStatus.monitoring
                        ? provider.stopMonitoring
                        : provider.startMonitoring,
                    icon: Icon(
                      provider.monitoringStatus == MonitoringStatus.monitoring
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                      color: provider.monitoringStatus ==
                              MonitoringStatus.monitoring
                          ? Colors.redAccent
                          : Colors.greenAccent,
                    ),
                    label: Text(
                      provider.monitoringStatus == MonitoringStatus.monitoring
                          ? 'Stop'
                          : 'Start',
                      style: TextStyle(
                        color: provider.monitoringStatus ==
                                MonitoringStatus.monitoring
                            ? Colors.redAccent
                            : Colors.greenAccent,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Seizure Alert (shows when seizure detected) ──
            const SeizureAlertWidget(),

            // ── Detection Status Card ──
            if (provider.museConnected) ...[
              _detectionCard(provider),
              const SizedBox(height: 16),
            ],

            // ── Muse Card ──
            _museCard(context, provider),
            const SizedBox(height: 16),

            // ── Watch Card ──
            _watchCard(context, provider),
            const SizedBox(height: 16),

            // ── Seizure History ──
            if (provider.seizureHistory.isNotEmpty)
              _historyCard(context, provider),
          ],
        ),
      ),
    );
  }

  // ─── DETECTION STATUS CARD ───────────────────────────────
  Widget _detectionCard(SeizureProvider provider) {
    final result = provider.lastResult;
    final isMonitoring =
        provider.monitoringStatus == MonitoringStatus.monitoring;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isMonitoring) {
      statusColor = Colors.grey;
      statusText  = 'Monitoring paused';
      statusIcon  = Icons.pause_circle_outline;
    } else if (result == null) {
      statusColor = Colors.blueAccent;
      statusText  = 'Waiting for first window...';
      statusIcon  = Icons.hourglass_top;
    } else {
      switch (result.status) {
        case DetectionStatus.normal:
          statusColor = Colors.greenAccent;
          statusText  = 'Normal brain activity';
          statusIcon  = Icons.check_circle_outline;
          break;
        case DetectionStatus.seizure:
          statusColor = Colors.redAccent;
          statusText  = 'Seizure detected!';
          statusIcon  = Icons.warning_rounded;
          break;
        case DetectionStatus.skipped:
          statusColor = Colors.orangeAccent;
          statusText  = 'Window skipped (artefact)';
          statusIcon  = Icons.skip_next;
          break;
        case DetectionStatus.error:
          statusColor = Colors.orangeAccent;
          statusText  = result.errorMessage ?? 'Unknown error';
          statusIcon  = Icons.error_outline;
          break;
        default:
          statusColor = Colors.grey;
          statusText  = 'Idle';
          statusIcon  = Icons.circle_outlined;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(width: 10),
              Text(statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          if (result?.probability != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: result!.probability,
              backgroundColor: Colors.grey.shade800,
              color: result.isSeizure ? Colors.redAccent : Colors.greenAccent,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              'Seizure probability: ${(result.probability! * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          // Buffer stats
          Row(
            children: [
              _statChip('Windows', '${provider.windowsProcessed}'),
              const SizedBox(width: 8),
              _statChip('Dropped samples', '${provider.droppedSamples}'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── MUSE CARD ───────────────────────────────────────────
  Widget _museCard(BuildContext context, SeizureProvider provider) {
    final state = provider.museState;

    Color statusColor;
    String statusLabel;
    switch (state) {
      case MuseConnectionState.connected:
        statusColor = Colors.greenAccent;
        statusLabel = 'Connected';
        break;
      case MuseConnectionState.connecting:
        statusColor = Colors.orangeAccent;
        statusLabel = 'Connecting...';
        break;
      case MuseConnectionState.scanning:
        statusColor = Colors.orangeAccent;
        statusLabel = 'Scanning...';
        break;
      case MuseConnectionState.disconnected:
        statusColor = Colors.redAccent;
        statusLabel = 'Disconnected';
        break;
    }

    return _card(
      title: 'Muse Gen 2',
      statusLabel: statusLabel,
      statusColor: statusColor,
      onConnect: state == MuseConnectionState.disconnected
          ? provider.connectMuse
          : null,
      onDisconnect: state == MuseConnectionState.connected
          ? provider.disconnectMuse
          : null,
      content: const Text(
        'EEG streaming active — data flowing to detection pipeline',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  // ─── WATCH CARD ──────────────────────────────────────────
  Widget _watchCard(BuildContext context, SeizureProvider provider) {
    final state = provider.watchState;
    final reading = provider.lastWatchReading;

    Color statusColor;
    String statusLabel;
    switch (state) {
      case WatchConnectionState.connected:
        statusColor = Colors.greenAccent;
        statusLabel = 'Connected';
        break;
      case WatchConnectionState.connecting:
        statusColor = Colors.orangeAccent;
        statusLabel = 'Connecting...';
        break;
      case WatchConnectionState.scanning:
        statusColor = Colors.orangeAccent;
        statusLabel = 'Scanning...';
        break;
      case WatchConnectionState.unsupported:
        statusColor = Colors.purpleAccent;
        statusLabel = 'Unsupported Protocol';
        break;
      case WatchConnectionState.disconnected:
        statusColor = Colors.redAccent;
        statusLabel = 'Disconnected';
        break;
    }

    return _card(
      title: 'Smartwatch',
      statusLabel: statusLabel,
      statusColor: statusColor,
      onConnect: state == WatchConnectionState.disconnected
          ? provider.connectWatch
          : null,
      onDisconnect: state == WatchConnectionState.connected
          ? provider.disconnectWatch
          : null,
      content: reading == null
          ? const Text('No data yet',
              style: TextStyle(color: Colors.grey, fontSize: 12))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dataRow('Heart Rate',
                    '${reading.heartRate} bpm', Colors.redAccent),
                if (reading.systolic != null)
                  _dataRow('Blood Pressure',
                      '${reading.systolic}/${reading.diastolic} mmHg',
                      Colors.blueAccent),
                if (reading.systolic == null)
                  const Text('BP not supported by this watch',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
    );
  }

  // ─── HISTORY CARD ────────────────────────────────────────
  Widget _historyCard(BuildContext context, SeizureProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Seizure History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: provider.clearHistory,
                child: const Text('Clear',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
          const Divider(color: Color(0xFF30363D), height: 20),
          ...provider.seizureHistory.map((event) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Colors.redAccent, size: 8),
                    const SizedBox(width: 10),
                    Text(event.timeString,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    const Spacer(),
                    Text(
                      '${(event.probability * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── SHARED WIDGETS ──────────────────────────────────────
  Widget _card({
    required String title,
    required String statusLabel,
    required Color statusColor,
    required Widget content,
    VoidCallback? onConnect,
    VoidCallback? onDisconnect,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12)),
            ],
          ),
          const Divider(color: Color(0xFF30363D), height: 24),
          content,
          const SizedBox(height: 16),
          Row(
            children: [
              if (onConnect != null)
                _btn('Connect', Colors.greenAccent, onConnect),
              if (onDisconnect != null)
                _btn('Disconnect', Colors.redAccent, onDisconnect),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Text('$label: $value',
          style: const TextStyle(color: Colors.grey, fontSize: 11)),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          foregroundColor: color,
        ),
        child: Text(label),
      ),
    );
  }
}