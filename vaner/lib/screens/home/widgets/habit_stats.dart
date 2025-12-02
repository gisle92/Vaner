import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../utils/date_key.dart';

/// 7-day stats: dots + % last 7d + streak (per habit)
class HabitStats extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String habitId;
  final String todayKey;

  const HabitStats({
    super.key,
    required this.logsRef,
    required this.habitId,
    required this.todayKey,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 6));
    final startKey = dateKeyFromDate(start);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef
          .where('habitId', isEqualTo: habitId)
          .where('date', isGreaterThanOrEqualTo: startKey)
          .where('date', isLessThanOrEqualTo: todayKey)
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 18);
        }

        final docs = snapshot.data?.docs ?? [];

        // Map date -> status
        final Map<String, String> byDate = {};
        for (final doc in docs) {
          final data = doc.data();
          final date = data['date'] as String?;
          final status = data['status'] as String?;
          if (date != null && status != null) {
            byDate[date] = status;
          }
        }

        // Last 7 days keys, oldest -> newest
        final days = List.generate(
          7,
          (i) => dateKeyFromDate(
            today.subtract(Duration(days: 6 - i)),
          ),
        );

        // Completion rate
        int doneCount = 0;
        for (final d in days) {
          if (byDate[d] == 'done') doneCount++;
        }
        final completionRate = doneCount / days.length;

        // Current streak (up to 7 days lookback)
        int streak = 0;
        for (int i = 0; i < days.length; i++) {
          final dKey = dateKeyFromDate(
            today.subtract(Duration(days: i)),
          );
          final status = byDate[dKey];
          if (status == 'done') {
            streak++;
          } else {
            break;
          }
        }

        return Row(
          children: [
            // 7 dots
            Row(
              children: days.map((dKey) {
                final status = byDate[dKey];
                Color color;
                if (status == 'done') {
                  color = Colors.teal;
                } else if (status == 'skipped') {
                  color = Colors.redAccent;
                } else {
                  color = Colors.grey.shade300;
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${(completionRate * 100).round()}% siste 7 dager • ${streak}d streak',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}
