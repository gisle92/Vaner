import 'package:flutter/material.dart';

class ShareSummaryCard extends StatelessWidget {
  final String dateLabel;
  final int total;
  final int done;

  const ShareSummaryCard({
    super.key,
    required this.dateLabel,
    required this.total,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Vaner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dagens fremgang',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(dateLabel, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          Text(
            '$done / $total vaner',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
