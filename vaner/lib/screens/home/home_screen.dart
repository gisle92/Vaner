import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../dialogs/new_habit_dialog.dart';
import '../../habit_suggestions.dart';
import '../../push_notifications.dart';
import '../../utils/date_key.dart';
import '../about_screen.dart';
import '../habit_detail_screen.dart';
import '../notification_settings_screen.dart';
import 'widgets/habit_stats.dart';
import 'widgets/home_header.dart';
import 'widgets/today_status.dart';
import 'widgets/today_summary_card.dart';

/// Home screen: show habits, summary, add habit, mark today as Done / Skipped
class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CollectionReference<Map<String, dynamic>> get _habitsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('habits');

  CollectionReference<Map<String, dynamic>> get _logsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('habitLogs');

  String get _todayKey => dateKeyFromDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    _ensureUserProfile();
    // Start push notifications (Android/iOS). Web is skipped inside init().
    PushNotifications().init(widget.user);
  }

  Future<void> _ensureUserProfile() async {
    final user = widget.user;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userRef.set(
      {
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'lastLoginAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _addHabitDialog() async {
    final result = await showDialog<NewHabitResult>(
      context: context,
      builder: (context) => const NewHabitDialog(),
    );

    if (result != null && result.name.trim().isNotEmpty) {
      await _habitsRef.add({
        'name': result.name.trim(),
        'categoryId': result.categoryId,
        'targetDays': result.targetDays,
        'createdAt': FieldValue.serverTimestamp(),
        'isArchived': false,
      });
    }
  }

  Future<void> _setStatus(String habitId, String status) async {
    // status: 'done' or 'skipped'
    final logId = '${habitId}_$_todayKey';
    await _logsRef.doc(logId).set(
      {
        'habitId': habitId,
        'date': _todayKey,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    setState(() {}); // trigger rebuild to refresh today's status
  }

  Future<void> _archiveHabit(String habitId, String name) async {
    try {
      await _habitsRef.doc(habitId).update({'isArchived': true});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arkiverte "$name".'),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunne ikke arkivere: $e')),
        );
      }
    }
  }

  Future<void> _deleteHabit(String habitId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Slett vane'),
          content: Text(
            'Dette vil slette "$name" og all historikk for denne vanen. '
            'Er du sikker?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Slett'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final logsSnap =
          await _logsRef.where('habitId', isEqualTo: habitId).get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in logsSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_habitsRef.doc(habitId));
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slettet "$name".'),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunne ikke slette vane: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final todayFormatted =
        DateFormat('EEEE d. MMMM').format(DateTime.now()); // system locale

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Om Vaner',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationSettingsScreen(userId: widget.user.uid),
                ),
              );
            },
            icon: const Icon(Icons.notifications),
            tooltip: 'Varsler',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Logg ut',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(user: widget.user, todayFormatted: todayFormatted),
              const SizedBox(height: 16),
              Text(
                'Dagens vaner',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _habitsRef
                      .where('isArchived', isEqualTo: false)
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Feil ved henting av vaner: ${snapshot.error}',
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.spa,
                                size: 40,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Ingen vaner enda',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Legg til 1–3 små vaner.\nDe skal være så små at du klarer dem på en dårlig dag.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _addHabitDialog,
                                child: const Text('Legg til første vane'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // When we have habits: show today summary + list
                    return Column(
                      children: [
                        TodaySummaryCard(
                          logsRef: _logsRef,
                          todayKey: _todayKey,
                          habitDocs: docs,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.only(top: 8, bottom: 80),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data();
                              final habitId = doc.id;
                              final name =
                                  data['name'] as String? ?? 'Uten navn';
                              final categoryId =
                                  data['categoryId'] as String? ?? 'other';
                              final category = habitCategories.firstWhere(
                                (c) => c.id == categoryId,
                                orElse: () => habitCategories.last,
                              );
                              final Object? targetDaysRaw = data['targetDays'];
                              final int? targetDays =
                                  targetDaysRaw is int ? targetDaysRaw : null;

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => HabitDetailScreen(
                                        userId: widget.user.uid,
                                        habitId: habitId,
                                        habitName: name,
                                        targetDays: targetDays,
                                      ),
                                    ),
                                  );
                                },
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.teal
                                                              .withOpacity(0.08),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(999),
                                                        ),
                                                        child: Text(
                                                          '${category.emoji} ${category.label}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      if (targetDays != null) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 6,
                                                            vertical: 3,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .amber
                                                                .withOpacity(
                                                                    0.12),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        999),
                                                          ),
                                                          child: Text(
                                                            '${targetDays}d mål',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              onSelected: (value) {
                                                switch (value) {
                                                  case 'archive':
                                                    _archiveHabit(
                                                        habitId, name);
                                                    break;
                                                  case 'delete':
                                                    _deleteHabit(
                                                        habitId, name);
                                                    break;
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'archive',
                                                  child: Text('Arkiver vane'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Slett vane'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TodayStatus(
                                                logsRef: _logsRef,
                                                habitId: habitId,
                                                todayKey: _todayKey,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton.icon(
                                              onPressed: () async {
                                                await _setStatus(
                                                    habitId, 'skipped');
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Notert. Du hoppet over "$name" i dag.',
                                                      ),
                                                      duration:
                                                          const Duration(
                                                              milliseconds:
                                                                  900),
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(Icons.close),
                                              label: const Text('Hopp over'),
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 6,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton.icon(
                                              onPressed: () async {
                                                await _setStatus(
                                                    habitId, 'done');
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Flott! Du gjorde "$name" ✅',
                                                      ),
                                                      duration:
                                                          const Duration(
                                                              milliseconds:
                                                                  900),
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(Icons.check),
                                              label: const Text('Gjort'),
                                              style: FilledButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        HabitStats(
                                          logsRef: _logsRef,
                                          habitId: habitId,
                                          todayKey: _todayKey,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHabitDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
