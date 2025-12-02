import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Today summary across ALL habits
class TodaySummaryCard extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String todayKey;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> habitDocs;

  const TodaySummaryCard({
    super.key,
    required this.logsRef,
    required this.todayKey,
    required this.habitDocs,
  });

  @override
  Widget build(BuildContext context) {
    if (habitDocs.isEmpty) return const SizedBox.shrink();

    final habitIds = habitDocs.map((d) => d.id).toSet();
    final totalHabits = habitIds.length;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: logsRef.where('date', isEqualTo: todayKey).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(width: 12),
                  Text(
                    'Beregner dagens progresjon…',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        int doneCount = 0;
        int skippedCount = 0;

        for (final doc in docs) {
          final data = doc.data();
          final habitId = data['habitId'] as String?;
          final status = data['status'] as String?;
          if (habitId != null && habitIds.contains(habitId)) {
            if (status == 'done') {
              doneCount++;
            } else if (status == 'skipped') {
              skippedCount++;
            }
          }
        }

        final notSetCount = totalHabits - doneCount - skippedCount;
        final completionRate =
            totalHabits == 0 ? 0.0 : doneCount / totalHabits.toDouble();

        String message;
        if (totalHabits == 0) {
          message = 'Ingen aktive vaner i dag.';
        } else if (doneCount == totalHabits) {
          message = 'Perfekt dag! Alle vaner gjort 🎉';
        } else if (completionRate >= 0.66) {
          message = 'Bra! Du er godt i gang i dag.';
        } else if (doneCount > 0) {
          message = 'God start, litt til så er du der.';
        } else {
          message = 'Små steg teller. Prøv å fullføre én vane.';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$doneCount / $totalHabits vaner gjort',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hoppet over: $skippedCount • Ikke satt: $notSetCount',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: completionRate.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
