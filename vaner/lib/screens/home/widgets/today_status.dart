import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Widget that shows today's status for a habit
class TodayStatus extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String habitId;
  final String todayKey;

  const TodayStatus({
    super.key,
    required this.logsRef,
    required this.habitId,
    required this.todayKey,
  });

  @override
  Widget build(BuildContext context) {
    final logId = '${habitId}_$todayKey';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: logsRef.doc(logId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            'I dag: …',
            style: TextStyle(color: Colors.grey),
          );
        }

        String status = 'none';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          status = data?['status'] as String? ?? 'none';
        }

        Color color;
        String label;
        IconData icon;

        switch (status) {
          case 'done':
            color = Colors.teal;
            label = 'Gjort';
            icon = Icons.check_circle;
            break;
          case 'skipped':
            color = Colors.redAccent;
            label = 'Hoppet over';
            icon = Icons.cancel;
            break;
          default:
            color = Colors.grey;
            label = 'Ikke satt';
            icon = Icons.radio_button_unchecked;
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Row(
            key: ValueKey(status),
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
