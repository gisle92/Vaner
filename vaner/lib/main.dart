import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
        // NOTE: CardThemeData (not CardTheme) to match new Flutter API
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

  Future<void> _signInWithGoogle() async {
    final provider = GoogleAuthProvider();

    if (kIsWeb) {
      // Web: popup sign-in
      await FirebaseAuth.instance.signInWithPopup(provider);
    } else {
      // Mobile / desktop: new provider API in firebase_auth 6.x
      await FirebaseAuth.instance.signInWithProvider(provider);
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
                        onPressed: _signInWithGoogle,
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

  Future<void> _addHabitDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ny vane'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'f.eks. 10 push-ups',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Avbryt'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.of(context).pop(text);
                }
              },
              child: const Text('Lagre'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _habitsRef.add({
        'name': result,
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

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => HabitDetailScreen(
                                        userId: widget.user.uid,
                                        habitId: habitId,
                                        habitName: name,
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
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                                              onPressed: () =>
                                                  _setStatus(habitId, 'skipped'),
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
                                              onPressed: () =>
                                                  _setStatus(habitId, 'done'),
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

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text(
            'I dag: ikke satt',
            style: TextStyle(color: Colors.grey),
          );
        }

        final data = snapshot.data!.data();
        final status = data?['status'] as String? ?? 'none';

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

        return Row(
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

/// Habit detail screen: 30-day stats
class HabitDetailScreen extends StatelessWidget {
  final String userId;
  final String habitId;
  final String habitName;

  const HabitDetailScreen({
    super.key,
    required this.userId,
    required this.habitId,
    required this.habitName,
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
    final startKey = _dateKeyFromDate(start);
    final todayKey = _dateKeyFromDate(today);

    return Scaffold(
      appBar: AppBar(
        title: Text(habitName),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _logsRef
                .where('habitId', isEqualTo: habitId)
                .where('date', isGreaterThanOrEqualTo: startKey)
                .where('date', isLessThanOrEqualTo: todayKey)
                .orderBy('date')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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

              // Last 30 days keys, oldest -> newest
              final days = List.generate(
                30,
                (i) => _dateKeyFromDate(
                  start.add(Duration(days: i)),
                ),
              );

              // Completion stats
              int doneCount = 0;
              int skippedCount = 0;
              for (final d in days) {
                final status = byDate[d];
                if (status == 'done') {
                  doneCount++;
                } else if (status == 'skipped') {
                  skippedCount++;
                }
              }
              final completionRate =
                  days.isEmpty ? 0.0 : doneCount / days.length;

              // Current streak (counting backwards from today)
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
                    Text(
                      'Siste 30 dager',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatChip(
                          label: 'Streak nå',
                          value: '${currentStreak}d',
                          icon: Icons.local_fire_department,
                        ),
                        const SizedBox(width: 8),
                        _StatChip(
                          label: 'Lengste streak',
                          value: '${longestStreak}d',
                          icon: Icons.emoji_events,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StatChip(
                      label: 'Fullført',
                      value: '${(completionRate * 100).round()}%',
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
    return Expanded(
      child: Container(
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
      ),
    );
  }
}

/// Helper: convert date to a daily key like "2025-11-24"
String _dateKeyFromDate(DateTime date) {
  final onlyDate = DateTime(date.year, date.month, date.day);
  return DateFormat('yyyy-MM-dd').format(onlyDate);
}
