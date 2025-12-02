import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../utils/date_key.dart';

/// Habit detail screen: 30-day stats + optional goal progress
class HabitDetailScreen extends StatelessWidget {
  final String userId;
  final String habitId;
  final String habitName;
  final int? targetDays;

  const HabitDetailScreen({
    super.key,
    required this.userId,
    required this.habitId,
    required this.habitName,
    required this.targetDays,
  });

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('habitLogs');

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 29)); // last 30 days
    final days = List.generate(
      30,
      (i) => dateKeyFromDate(
        start.add(Duration(days: i)),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(habitName),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: _logsRef.where('habitId', isEqualTo: habitId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Feil ved henting av historikk: ${snapshot.error}',
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              // Map date -> status for all time
              final Map<String, String> byDate = {};
              for (final doc in docs) {
                final data = doc.data();
                final date = data['date'] as String?;
                final status = data['status'] as String?;
                if (date != null && status != null) {
                  byDate[date] = status;
                }
              }

              // Last 30 days stats
              int doneLast30 = 0;
              int skippedLast30 = 0;
              for (final d in days) {
                final status = byDate[d];
                if (status == 'done') {
                  doneLast30++;
                } else if (status == 'skipped') {
                  skippedLast30++;
                }
              }
              final completionRateLast30 =
                  days.isEmpty ? 0.0 : doneLast30 / days.length;

              // All-time done count for goal progress
              int doneAllTime = 0;
              for (final doc in docs) {
                final data = doc.data();
                final status = data['status'] as String?;
                if (status == 'done') {
                  doneAllTime++;
                }
              }

              // Current streak (counting backwards from today, max 30 days)
              int currentStreak = 0;
              for (int i = 0; i < days.length; i++) {
                final dKey = dateKeyFromDate(
                  today.subtract(Duration(days: i)),
                );
                final status = byDate[dKey];
                if (status == 'done') {
                  currentStreak++;
                } else {
                  break;
                }
              }

              // Longest streak within last 30 days
              int longestStreak = 0;
              int running = 0;
              for (final d in days) {
                if (byDate[d] == 'done') {
                  running++;
                  if (running > longestStreak) {
                    longestStreak = running;
                  }
                } else {
                  running = 0;
                }
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (targetDays != null && targetDays! > 0) ...[
                      Text(
                        'Mål for denne vanen',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _GoalCard(
                        targetDays: targetDays!,
                        doneAllTime: doneAllTime,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Siste 30 dager',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatChip(
                            label: 'Streak nå',
                            value: '${currentStreak}d',
                            icon: Icons.local_fire_department,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatChip(
                            label: 'Lengste streak',
                            value: '${longestStreak}d',
                            icon: Icons.emoji_events,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StatChip(
                      label: 'Fullført (30 dager)',
                      value: '${(completionRateLast30 * 100).round()}%',
                      icon: Icons.check_circle,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Daglig historikk',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hver rute er én dag. Grønn = gjort, rød = hoppet over, grå = ingen data.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
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
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final int targetDays;
  final int doneAllTime;

  const _GoalCard({
    required this.targetDays,
    required this.doneAllTime,
  });

  @override
  Widget build(BuildContext context) {
    final reached = doneAllTime >= targetDays;
    final progress =
        targetDays > 0 ? (doneAllTime / targetDays).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.emoji_events : Icons.flag,
                color: Colors.teal,
              ),
              const SizedBox(width: 8),
              Text(
                reached ? 'Mål nådd 🎉' : 'Mål: $targetDays dager',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Fullført totalt: $doneAllTime / $targetDays dager',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            spreadRadius: 1,
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.teal),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
