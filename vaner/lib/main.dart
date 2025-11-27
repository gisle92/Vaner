import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'habit_suggestions.dart';
import 'push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const VanerApp());
}

class VanerApp extends StatelessWidget {
  const VanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Vaner',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: baseTheme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          color: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          shape: CircleBorder(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Auth gate – shows either SignInScreen or HomeScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const SignInScreen();
        }

        return HomeScreen(user: user);
      },
    );
  }
}

/// Simple Google sign-in screen with nicer styling
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    final provider = GoogleAuthProvider();

    try {
      if (kIsWeb) {
        // Web: popup sign-in
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // Mobile / desktop: new provider API in firebase_auth 6.x
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke logge inn: ${e.code}')),
      );
      debugPrint('FirebaseAuthException: ${e.code} – ${e.message}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ukjent feil ved innlogging')),
      );
      debugPrint('Unknown sign-in error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF14B8A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 48,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Vaner',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bygg gode vaner på 10 sekunder om dagen.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _signInWithGoogle(context),
                        icon: const Icon(Icons.login),
                        label: const Text('Logg inn med Google'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

  String get _todayKey => _dateKeyFromDate(DateTime.now());

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
    final result = await showDialog<_NewHabitResult>(
      context: context,
      builder: (context) => const _NewHabitDialog(),
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
              _Header(user: widget.user, todayFormatted: todayFormatted),
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
                        _TodaySummaryCard(
                          logsRef: _logsRef,
                          todayKey: _todayKey,
                          habitDocs: docs,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.only(top: 8, bottom: 80),
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
                              final Object? targetDaysRaw =
                                  data['targetDays'];
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
                                                              .withOpacity(
                                                                  0.08),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      999),
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
                                                        const SizedBox(
                                                            width: 6),
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
                                              child: _TodayStatus(
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
                                        _HabitStats(
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

/// Header with avatar, greeting and date
class _Header extends StatelessWidget {
  final User user;
  final String todayFormatted;

  const _Header({
    required this.user,
    required this.todayFormatted,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = (user.displayName ?? 'venn').split(' ').first;
    final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage:
              user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          child: user.photoURL == null
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hei, $firstName 👋',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              todayFormatted,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Widget that shows today's status for a habit
class _TodayStatus extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String habitId;
  final String todayKey;

  const _TodayStatus({
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

/// 7-day stats: dots + % last 7d + streak (per habit)
class _HabitStats extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String habitId;
  final String todayKey;

  const _HabitStats({
    required this.logsRef,
    required this.habitId,
    required this.todayKey,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 6));
    final startKey = _dateKeyFromDate(start);

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
          (i) => _dateKeyFromDate(
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
          final dKey = _dateKeyFromDate(
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

/// Today summary across ALL habits
class _TodaySummaryCard extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> logsRef;
  final String todayKey;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> habitDocs;

  const _TodaySummaryCard({
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
      (i) => _dateKeyFromDate(
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
                final dKey = _dateKeyFromDate(
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
                      value:
                          '${(completionRateLast30 * 100).round()}%',
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

/// Goal card shown when targetDays is set
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
    final progress = targetDays > 0
        ? (doneAllTime / targetDays).clamp(0.0, 1.0)
        : 0.0;

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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small stat card
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

/// Add-habit dialog: categories + suggestions + optional duration
class _NewHabitResult {
  final String name;
  final String categoryId;
  final int? targetDays;

  _NewHabitResult({
    required this.name,
    required this.categoryId,
    required this.targetDays,
  });
}

class _NewHabitDialog extends StatefulWidget {
  const _NewHabitDialog();

  @override
  State<_NewHabitDialog> createState() => _NewHabitDialogState();
}

class _NewHabitDialogState extends State<_NewHabitDialog> {
  late String _selectedCategoryId;
  final TextEditingController _controller = TextEditingController();
  int? _targetDays;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = habitCategories.first.id;
    _targetDays = null; // no goal by default
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectSuggestion(String text) {
    setState(() {
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        habitSuggestions[_selectedCategoryId] ?? const <String>[];
    final durationOptions = <int?>[null, 14, 30, 60, 90];

    return AlertDialog(
      title: const Text('Ny vane'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Velg kategori',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: habitCategories.map((cat) {
                final selected = cat.id == _selectedCategoryId;
                return ChoiceChip(
                  label: Text('${cat.emoji} ${cat.label}'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategoryId = cat.id;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (suggestions.isNotEmpty) ...[
              const Text(
                'Forslag',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: suggestions.map((s) {
                  return ActionChip(
                    label: Text(s),
                    onPressed: () => _selectSuggestion(s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Varighet (valgfritt)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: durationOptions.map((value) {
                final selected = _targetDays == value;
                String label;
                if (value == null) {
                  label = 'Ingen mål';
                } else {
                  label = '$value dager';
                }
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _targetDays = value;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Eller skriv din egen',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'f.eks. 10 push-ups',
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop(
                _NewHabitResult(
                  name: text,
                  categoryId: _selectedCategoryId,
                  targetDays: _targetDays,
                ),
              );
            }
          },
          child: const Text('Lagre'),
        ),
      ],
    );
  }
}

/// Notification settings (stored in Firestore, backend can later read this)
class NotificationSettingsScreen extends StatefulWidget {
  final String userId;

  const NotificationSettingsScreen({super.key, required this.userId});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('settings')
          .doc('notification');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snap = await _settingsDoc.get();
    if (snap.exists) {
      final data = snap.data()!;
      _enabled = (data['enabled'] as bool?) ?? false;
      final minuteOfDay = (data['minuteOfDay'] as int?) ?? (20 * 60);
      _time = TimeOfDay(
        hour: minuteOfDay ~/ 60,
        minute: minuteOfDay % 60,
      );
    }
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final minuteOfDay = _time.hour * 60 + _time.minute;

    final data = {
      'enabled': _enabled,
      'minuteOfDay': minuteOfDay,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Keep existing subcollection doc
    await _settingsDoc.set(
      data,
      SetOptions(merge: true),
    );

    // Mirror settings on the user root doc for easier backend queries
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .set(
      {
        'notification': data,
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Varslingsinnstillinger lagret')),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() {
        _time = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Varsler'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Daglig påminnelse'),
                    subtitle: const Text(
                        'Lagre når du vil få påminnelse om dagens vaner.'),
                    value: _enabled,
                    onChanged: (val) {
                      setState(() {
                        _enabled = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    enabled: _enabled,
                    onTap: _enabled ? _pickTime : null,
                    leading: const Icon(Icons.schedule),
                    title: const Text('Tidspunkt'),
                    subtitle: Text(_time.format(context)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Lagre'),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Helper: convert date to a daily key like "2025-11-24"
String _dateKeyFromDate(DateTime date) {
  final onlyDate = DateTime(date.year, date.month, date.day);
  return DateFormat('yyyy-MM-dd').format(onlyDate);
}
