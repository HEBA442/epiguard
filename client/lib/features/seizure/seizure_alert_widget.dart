import 'package:flutter/material.dart';
import 'seizure_provider.dart';
import 'package:provider/provider.dart';

class SeizureAlertWidget extends StatefulWidget {
  const SeizureAlertWidget({super.key});

  @override
  State<SeizureAlertWidget> createState() => _SeizureAlertWidgetState();
}

class _SeizureAlertWidgetState extends State<SeizureAlertWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SeizureProvider>();
    if (!provider.seizureActive) return const SizedBox.shrink();

    final latest = provider.seizureHistory.isNotEmpty
        ? provider.seizureHistory.first
        : null;

    return ScaleTransition(
      scale: _pulse,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF3D0000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 4,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: Colors.redAccent, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'SEIZURE DETECTED',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: provider.dismissSeizureAlert,
                  child: const Icon(Icons.close,
                      color: Colors.redAccent, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Probability
            if (latest != null) ...[
              _alertRow(
                'Confidence',
                '${(latest.probability * 100).toStringAsFixed(1)}%',
              ),
              _alertRow('Detected at', latest.timeString),
            ],
            const SizedBox(height: 16),

            // Dismiss button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.dismissSeizureAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Dismiss Alert',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}